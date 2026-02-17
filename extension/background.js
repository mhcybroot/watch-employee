// State variables
let currentTabId = null;
let currentUrl = null;
let startTime = Date.now();
const IDLE_THRESHOLD = 60; // 60 seconds
const BATCH_INTERVAL = 2 * 60 * 1000; // 2 minutes
const API_URL = "http://127.0.0.1:8565/api/activity/batch";
const USER_EMAIL = "user@example.com"; // Hardcoded for demo

// Initialize storage and device ID
let deviceId = null;

// Initialize once on startup
browser.storage.local.get(["activityLogs", "deviceId"]).then((data) => {
    if (!data.activityLogs) {
        browser.storage.local.set({ activityLogs: [] });
    }

    if (data.deviceId) {
        deviceId = data.deviceId;
        console.log("Device ID loaded:", deviceId);
    } else {
        console.log("No Device ID found. Redirecting to setup...");
        browser.tabs.create({ url: "setup.html" });
    }
});

// Watch for storage changes (to pick up deviceId after setup)
browser.storage.onChanged.addListener((changes, area) => {
    if (area === "local" && changes.deviceId) {
        deviceId = changes.deviceId.newValue;
        console.log("Device ID updated from storage:", deviceId);
    }
});

function logActivity(endTime) {
    if (currentUrl && startTime) {
        const duration = Math.round((endTime - startTime) / 1000);
        if (duration > 0) {
            const log = {
                userEmail: USER_EMAIL,
                url: currentUrl,
                startTime: new Date(startTime).toISOString(),
                endTime: new Date(endTime).toISOString(),
                durationSeconds: duration,
                deviceId: deviceId
            };

            browser.storage.local.get("activityLogs").then((data) => {
                const logs = data.activityLogs || [];
                logs.push(log);
                browser.storage.local.set({ activityLogs: logs });
            });
        }
    }
}

function updateState(tabId, url) {
    const now = Date.now();
    logActivity(now);

    currentTabId = tabId;
    currentUrl = url;
    startTime = now;
}

// Listen for tab activation
browser.tabs.onActivated.addListener(async (activeInfo) => {
    const tab = await browser.tabs.get(activeInfo.tabId);
    if (tab.url) {
        updateState(activeInfo.tabId, tab.url);
    }
});

// Listen for URL changes
browser.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
    if (tabId === currentTabId && changeInfo.url) {
        updateState(tabId, changeInfo.url);
    }
});

// Listen for idle state
browser.idle.setDetectionInterval(IDLE_THRESHOLD);
browser.idle.onStateChanged.addListener((state) => {
    const now = Date.now();
    if (state === "idle" || state === "locked") {
        logActivity(now);
        currentUrl = null; // Stop tracking
    } else if (state === "active") {
        browser.tabs.query({ active: true, currentWindow: true }).then((tabs) => {
            if (tabs.length > 0) {
                updateState(tabs[0].id, tabs[0].url);
            }
        });
    }
});

// Batch send to backend
setInterval(async () => {
    const data = await browser.storage.local.get("activityLogs");
    const logsToSend = data.activityLogs || [];

    if (logsToSend.length > 0) {
        try {
            const response = await fetch(API_URL, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json"
                },
                body: JSON.stringify(logsToSend)
            });

            if (response.ok) {
                console.log(`Successfully sent ${logsToSend.length} logs.`);

                // Safely remove sent logs
                const currentData = await browser.storage.local.get("activityLogs");
                const currentLogs = currentData.activityLogs || [];
                // Remove the number of logs we sent from the beginning of the array
                // any new logs added during fetch will be at the end
                const remainingLogs = currentLogs.slice(logsToSend.length);

                await browser.storage.local.set({ activityLogs: remainingLogs });
            } else {
                console.error("Server error, keeping logs in storage.");
            }
        } catch (error) {
            console.error("Network error, keeping logs in storage.", error);
        }
    }
}, BATCH_INTERVAL);
