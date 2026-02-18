// State variables
let currentTabId = null;
let currentUrl = null;
let startTime = Date.now();
const IDLE_THRESHOLD = 60; // 60 seconds
const BATCH_INTERVAL = 2 * 60 * 1000; // 2 minutes
const API_URL = "http://127.0.0.1:8565/api/activity/batch";

// Initialize state
let deviceId = null;
let userEmail = null;

// Initialize once on startup
browser.storage.local.get(["activityLogs", "deviceId", "userEmail"]).then((data) => {
    if (!data.activityLogs) {
        browser.storage.local.set({ activityLogs: [] });
    }

    if (data.deviceId && data.userEmail) {
        deviceId = data.deviceId;
        userEmail = data.userEmail;
        console.log("Configuration loaded:", { deviceId, userEmail });
    } else {
        console.log("Configuration incomplete. Redirecting to setup...");
        browser.tabs.create({ url: "setup.html" });
    }
});

// Watch for storage changes (to pick up config after setup)
browser.storage.onChanged.addListener((changes, area) => {
    if (area === "local") {
        if (changes.deviceId) deviceId = changes.deviceId.newValue;
        if (changes.userEmail) userEmail = changes.userEmail.newValue;
        console.log("Configuration updated:", { deviceId, userEmail });
    }
});

function logActivity(endTime) {
    if (currentUrl && startTime && deviceId && userEmail) {
        const duration = Math.round((endTime - startTime) / 1000);
        if (duration > 0) {
            const log = {
                userEmail: userEmail,
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

const API_KEY = "productivity-secret-key-2024";

const BLOCKING_API_URL = "http://127.0.0.1:8565/api/blocked-sites";
let globalBlockedDomains = []; // Cache for fallback check

async function updateBlockingRules() {
    if (!deviceId) return;

    try {
        const response = await fetch(`${BLOCKING_API_URL}?deviceId=${deviceId}`);
        if (response.ok) {
            const blockedDomains = await response.json();
            globalBlockedDomains = blockedDomains; // Update cache

            // Convert domains to Regex DNR rules
            // Regex: ^https?://([a-z0-9-]+\.)*domain\.com(/.*)?$
            const newRules = blockedDomains.map((domain, index) => {
                // Escape dots for regex
                const escapedDomain = domain.replace(/\./g, '\\.');
                const regex = `^https?://([a-z0-9-]+\\.)*${escapedDomain}(/.*)?$`;

                return {
                    id: index + 1,
                    priority: 1,
                    action: { type: "block" },
                    condition: {
                        regexFilter: regex,
                        resourceTypes: ["main_frame", "xmlhttprequest"]
                    }
                };
            });

            // Get existing rules to remove them first
            const oldRules = await chrome.declarativeNetRequest.getDynamicRules();
            const oldRuleIds = oldRules.map(rule => rule.id);

            // Update rules
            await chrome.declarativeNetRequest.updateDynamicRules({
                removeRuleIds: oldRuleIds,
                addRules: newRules
            });

            console.log(`Updated blocking rules: ${blockedDomains.length} domains blocked.`);
        }
    } catch (error) {
        console.error("Failed to update blocking rules:", error);
    }
}

// Fallback: Check navigations client-side (SPA support)
browser.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
    if (changeInfo.url && globalBlockedDomains.length > 0) {
        try {
            const url = new URL(changeInfo.url);
            // Check if hostname ends with any blocked domain
            const match = globalBlockedDomains.some(domain =>
                url.hostname === domain || url.hostname.endsWith("." + domain)
            );

            if (match) {
                console.log("Fallback blocking: " + url.hostname);
                browser.tabs.update(tabId, { url: "blocked.html" }); // Create this file or redirect to generic page
            }
        } catch (e) {
            // Invalid URL, ignore
        }
    }
});

// Update rules periodically and on startup
setInterval(updateBlockingRules, BATCH_INTERVAL);
// Also update when deviceId is loaded
browser.storage.onChanged.addListener((changes, area) => {
    if (area === "local" && changes.deviceId) {
        updateBlockingRules();
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
                    "Content-Type": "application/json",
                    "X-API-KEY": API_KEY
                },
                body: JSON.stringify(logsToSend)
            });

            if (response.ok) {
                console.log(`Successfully sent ${logsToSend.length} logs.`);
                await updateBlockingRules(); // Also update rules after sending logs

                // Safely remove sent logs
                const currentData = await browser.storage.local.get("activityLogs");
                const currentLogs = currentData.activityLogs || [];
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

