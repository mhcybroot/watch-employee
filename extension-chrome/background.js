// State variables
importScripts('config.js');

let currentTabId = null;
let currentUrl = null;
let startTime = Date.now();
const IDLE_THRESHOLD = 60; // 60 seconds

const API_URL = `${SERVER_URL}/api/activity/batch`;
const BLOCKING_API_URL = `${SERVER_URL}/api/blocked-sites`;

// Initialize state
let deviceId = null;
let userEmail = null;

// Initialize once on startup
chrome.storage.local.get(["activityLogs", "deviceId", "userEmail"]).then(async (data) => {
    if (!data.activityLogs) {
        chrome.storage.local.set({ activityLogs: [] });
    }

    if (data.deviceId && data.userEmail) {
        deviceId = data.deviceId;
        userEmail = data.userEmail;
        console.log("Configuration loaded:", { deviceId, userEmail });

        // Health Check on Startup
        try {
            const response = await fetch(`${SERVER_URL}/api/blocked-sites?deviceId=${deviceId}`);
            if (!response.ok) {
                console.warn("Server Check Failed (Status Code):", response.status);
                chrome.tabs.create({ url: "error.html" });
            }
        } catch (error) {
            console.warn("Server Check Failed (Network):", error);
            chrome.tabs.create({ url: "error.html" });
        }

    } else {
        console.log("Configuration incomplete. Redirecting to setup...");
        chrome.tabs.create({ url: "setup.html" });
    }
});

// Watch for storage changes (to pick up config after setup)
chrome.storage.onChanged.addListener((changes, area) => {
    if (area === "local") {
        if (changes.deviceId) deviceId = changes.deviceId.newValue;
        if (changes.userEmail) userEmail = changes.userEmail.newValue;
        console.log("Configuration updated:", { deviceId, userEmail });
    }
});

// Helper: Check if URL should be tracked (only http/https)
function isTrackableUrl(url) {
    return url && (url.startsWith('http://') || url.startsWith('https://'));
}

// Helper: Flushes the current in-memory log to storage and resets the timer
async function flushCurrentJournal() {
    if (currentUrl && isTrackableUrl(currentUrl) && startTime && deviceId && userEmail) {
        const now = Date.now();
        const duration = Math.round((now - startTime) / 1000);

        if (duration > 0) {
            const log = {
                userEmail: userEmail,
                url: currentUrl,
                startTime: new Date(startTime).toISOString(),
                endTime: new Date(now).toISOString(),
                durationSeconds: duration,
                deviceId: deviceId
            };

            try {
                const data = await chrome.storage.local.get("activityLogs");
                const logs = data.activityLogs || [];
                logs.push(log);
                await chrome.storage.local.set({ activityLogs: logs });
                console.log("Checkpointed log:", { url: currentUrl, duration });
            } catch (e) {
                console.error("Failed to save log:", e);
            }

            // Reset start time to now to prevent double counting
            startTime = now;
        }
    }
}

async function updateState(tabId, url) {
    await flushCurrentJournal(); // Save previous activity

    currentTabId = tabId;
    currentUrl = url;
    startTime = Date.now();
}

// Listen for tab activation
chrome.tabs.onActivated.addListener(async (activeInfo) => {
    const tab = await chrome.tabs.get(activeInfo.tabId);
    if (tab.url) {
        updateState(activeInfo.tabId, tab.url);
    }
});

// Listen for URL changes
chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
    if (tabId === currentTabId && changeInfo.url) {
        updateState(tabId, changeInfo.url);
    }
});

// Listen for idle state
chrome.idle.setDetectionInterval(IDLE_THRESHOLD);
chrome.idle.onStateChanged.addListener(async (state) => {
    if (state === "idle" || state === "locked") {
        await flushCurrentJournal();
        currentUrl = null; // Stop tracking
    } else if (state === "active") {
        chrome.tabs.query({ active: true, currentWindow: true }).then((tabs) => {
            if (tabs.length > 0) {
                updateState(tabs[0].id, tabs[0].url);
            }
        });
    }
});

const API_KEY = "productivity-secret-key-2024";

// BLOCKING_API_URL is now defined at the top using SERVER_URL
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
chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
    if (changeInfo.url && globalBlockedDomains.length > 0) {
        try {
            const url = new URL(changeInfo.url);

            // Ignore internal pages (about:, chrome:, file:, etc.)
            if (!url.protocol.startsWith('http')) {
                return;
            }

            // Check if hostname ends with any blocked domain
            const match = globalBlockedDomains.some(domain =>
                url.hostname === domain || url.hostname.endsWith("." + domain)
            );

            if (match) {
                console.log("Fallback blocking: " + url.hostname);
                chrome.tabs.update(tabId, { url: "blocked.html" }); // Create this file or redirect to generic page
            }
        } catch (e) {
            // Invalid URL, ignore
        }
    }
});

// Use Alarms for Service Worker capability (setInterval is unreliable)
chrome.alarms.create("batchUpload", { periodInMinutes: 1 });
chrome.alarms.create("updateRules", { periodInMinutes: 1 });

chrome.alarms.onAlarm.addListener(async (alarm) => {
    console.log(`[DEBUG] Alarm fired: ${alarm.name}`);
    if (alarm.name === "batchUpload") {
        await sendBatchData();
    } else if (alarm.name === "updateRules") {
        await updateBlockingRules();
    }
});

async function sendBatchData() {
    console.log("[DEBUG] sendBatchData started");
    await flushCurrentJournal(); // Ensure active session is saved before sending

    const data = await chrome.storage.local.get("activityLogs");
    const logsToSend = data.activityLogs || [];
    console.log(`[DEBUG] Logs to send: ${logsToSend.length}`);

    if (logsToSend.length > 0) {
        try {
            console.log(`[DEBUG] Sending to ${API_URL}...`);
            const response = await fetch(API_URL, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    "X-API-KEY": API_KEY
                },
                body: JSON.stringify(logsToSend)
            });

            console.log(`[DEBUG] Fetch response status: ${response.status}`);

            if (response.ok) {
                console.log(`Successfully sent ${logsToSend.length} logs.`);
                await updateBlockingRules();

                // Safely remove only the logs we successfully sent
                await chrome.storage.local.set({ activityLogs: [] });
            } else {
                console.error("Server error, keeping logs in storage.");
                const text = await response.text();
                console.error("Server response body:", text);
            }
        } catch (error) {
            console.error("Network error, keeping logs in storage.", error);
        }
    } else {
        console.log("[DEBUG] No logs to send.");
    }
}

