// State variables
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
browser.storage.local.get(["activityLogs", "deviceId", "userEmail"]).then(async (data) => {
    if (!data.activityLogs) {
        browser.storage.local.set({ activityLogs: [] });
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
                browser.tabs.create({ url: "error.html" });
            }
        } catch (error) {
            console.warn("Server Check Failed (Network):", error);
            browser.tabs.create({ url: "error.html" });
        }

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

// Helper: Format date as local ISO string (YYYY-MM-DDTHH:mm:ss) instead of UTC
function toLocalISOString(date) {
    const d = new Date(date);
    const pad = (n) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}

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
                startTime: toLocalISOString(startTime),
                endTime: toLocalISOString(now),
                durationSeconds: duration,
                deviceId: deviceId
            };

            try {
                const data = await browser.storage.local.get("activityLogs");
                const logs = data.activityLogs || [];
                logs.push(log);
                await browser.storage.local.set({ activityLogs: logs });
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
browser.idle.onStateChanged.addListener(async (state) => {
    if (state === "idle" || state === "locked") {
        await flushCurrentJournal();
        currentUrl = null; // Stop tracking
    } else if (state === "active") {
        browser.tabs.query({ active: true, currentWindow: true }).then((tabs) => {
            if (tabs.length > 0) {
                updateState(tabs[0].id, tabs[0].url);
            }
        });
    }
});

const API_KEY = EXTENSION_API_KEY;

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
            const oldRules = await browser.declarativeNetRequest.getDynamicRules();
            const oldRuleIds = oldRules.map(rule => rule.id);

            // Update rules
            await browser.declarativeNetRequest.updateDynamicRules({
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
                browser.tabs.update(tabId, { url: "blocked.html" }); // Create this file or redirect to generic page
            }
        } catch (e) {
            // Invalid URL, ignore
        }
    }
});

// Use Alarms for Event Page capability (setInterval is unreliable in MV3)
browser.alarms.create("batchUpload", { periodInMinutes: 1 });
browser.alarms.create("updateRules", { periodInMinutes: 1 });

browser.alarms.onAlarm.addListener(async (alarm) => {
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

    const data = await browser.storage.local.get("activityLogs");
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
                await updateBlockingRules(); // Also update rules after sending logs

                // Safely remove only the logs we successfully sent
                await browser.storage.local.set({ activityLogs: [] });
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

// ==================== Auto-Fill Message Handlers ====================

const CREDENTIAL_API_KEY = EXTENSION_API_KEY;

browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.type === 'check-autofill') {
        handleCheckAutofill(message).then(sendResponse);
        return true; // async response
    }
    if (message.type === 'get-password') {
        handleGetPassword(message).then(sendResponse);
        return true;
    }
    if (message.type === 'save-credential') {
        handleSaveCredential(message).then(sendResponse);
        return true;
    }
});

async function handleCheckAutofill(message) {
    if (!deviceId) return { credentials: [] };
    try {
        const response = await fetch(
            `${SERVER_URL}/api/credentials?deviceId=${encodeURIComponent(deviceId)}`,
            { headers: { "X-API-KEY": CREDENTIAL_API_KEY } }
        );
        if (!response.ok) return { credentials: [] };
        const credentials = await response.json();
        return { credentials };
    } catch (err) {
        console.error("[AutoFill] Failed to fetch credentials:", err);
        return { credentials: [] };
    }
}

async function handleGetPassword(message) {
    if (!deviceId) return { error: "Not configured" };
    try {
        const response = await fetch(
            `${SERVER_URL}/api/credentials/${message.credentialId}/copy?deviceId=${encodeURIComponent(deviceId)}`,
            { headers: { "X-API-KEY": CREDENTIAL_API_KEY } }
        );
        if (response.status === 403) return { error: "Access denied" };
        if (!response.ok) return { error: "Server error" };
        const data = await response.json();
        return { password: data.password };
    } catch (err) {
        console.error("[AutoFill] Failed to get password:", err);
        return { error: "Connection failed" };
    }
}

async function handleSaveCredential(message) {
    if (!deviceId) return { success: false, error: "Not configured" };
    try {
        const response = await fetch(`${SERVER_URL}/api/credentials`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-API-KEY': CREDENTIAL_API_KEY
            },
            body: JSON.stringify({
                deviceId: deviceId,
                siteName: message.siteName,
                siteUrl: message.siteUrl,
                username: message.username,
                password: message.password,
                notes: 'Auto-saved from browser'
            })
        });
        if (!response.ok) return { success: false, error: "Server error" };
        return { success: true };
    } catch (err) {
        console.error("[AutoSave] Failed to save credential:", err);
        return { success: false, error: "Connection failed" };
    }
}
