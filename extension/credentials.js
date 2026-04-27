const API_KEY = EXTENSION_API_KEY;
let deviceId = null;
let allCredentials = [];
let myCredentials = [];
let activeTab = 'shared';

async function init() {
    try {
        const data = await new Promise((resolve, reject) => {
            if (typeof browser !== 'undefined') {
                browser.storage.local.get(["deviceId"]).then(resolve).catch(reject);
            } else {
                chrome.storage.local.get(["deviceId"], (result) => {
                    if (chrome.runtime.lastError) reject(chrome.runtime.lastError);
                    else resolve(result);
                });
            }
        });

        deviceId = data.deviceId;
        if (!deviceId) {
            showError("Device not configured. Please complete setup first.");
            return;
        }

        document.getElementById('deviceIdBadge').textContent = deviceId;
        await loadCredentials();

        // Wire up search
        const searchInput = document.getElementById('searchInput');
        if (searchInput) {
            searchInput.addEventListener('input', () => {
                const query = searchInput.value.trim().toLowerCase();
                if (!query) {
                    renderCredentials(allCredentials);
                    return;
                }
                const filtered = allCredentials.filter(c =>
                    (c.siteName && c.siteName.toLowerCase().includes(query)) ||
                    (c.siteUrl && c.siteUrl.toLowerCase().includes(query)) ||
                    (c.username && c.username.toLowerCase().includes(query)) ||
                    (c.notes && c.notes.toLowerCase().includes(query))
                );
                renderCredentials(filtered);
                if (filtered.length === 0) {
                    document.getElementById('credentialsList').innerHTML =
                        '<div class="no-results">No credentials match your search.</div>';
                }
            });
        }

        // Wire up tabs
        document.querySelectorAll('.tab-btn').forEach(btn => {
            btn.addEventListener('click', () => switchTab(btn.getAttribute('data-tab')));
        });

        // Wire up save button
        const saveBtn = document.getElementById('saveCredBtn');
        if (saveBtn) {
            saveBtn.addEventListener('click', submitCredential);
        }
    } catch (err) {
        showError("Failed to read configuration: " + err.message);
    }
}

// ==================== Tab Switching ====================

function switchTab(tab) {
    activeTab = tab;
    document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
    document.querySelector(`[data-tab="${tab}"]`).classList.add('active');

    const sharedSection = document.getElementById('sharedSection');
    const mySavedSection = document.getElementById('mySavedSection');

    if (tab === 'shared') {
        sharedSection.classList.remove('section-hidden');
        mySavedSection.classList.add('section-hidden');
    } else {
        sharedSection.classList.add('section-hidden');
        mySavedSection.classList.remove('section-hidden');
        loadMyCredentials();
    }
}

// ==================== Shared Credentials ====================

async function loadCredentials() {
    try {
        const response = await fetch(`${SERVER_URL}/api/credentials?deviceId=${encodeURIComponent(deviceId)}`, {
            headers: { "X-API-KEY": API_KEY }
        });

        document.getElementById('loading').style.display = 'none';

        if (!response.ok) {
            if (response.status === 401) {
                showError("Authentication failed. Invalid API key.");
            } else {
                showError(`Server error (${response.status}). Please try again.`);
            }
            return;
        }

        const credentials = await response.json();
        allCredentials = credentials;

        if (credentials.length === 0) {
            document.getElementById('credentialsList').innerHTML = `
                <div class="empty-state">
                    <div class="icon">🔑</div>
                    <p><strong>No credentials available</strong></p>
                    <p style="font-size: 0.85em; margin-top: 5px;">
                        Your admin hasn't assigned any credentials to your device yet.
                    </p>
                </div>
            `;
            return;
        }

        document.getElementById('statusBar').style.display = 'flex';
        document.getElementById('statusText').textContent = `${credentials.length} credential${credentials.length > 1 ? 's' : ''} available`;
        document.getElementById('searchContainer').style.display = 'block';

        renderCredentials(credentials);
    } catch (err) {
        document.getElementById('loading').style.display = 'none';
        showError("Cannot connect to server. Error: " + err.message);
    }
}

function renderCredentials(credentials) {
    const container = document.getElementById('credentialsList');
    container.innerHTML = credentials.map(cred => `
        <div class="credential-card">
            <div class="cred-header">
                <div>
                    <div class="site-name">${escapeHtml(cred.siteName)}</div>
                    <a href="${escapeHtml(cred.siteUrl)}" target="_blank" class="site-url">${escapeHtml(cred.siteUrl)}</a>
                </div>
            </div>
            <div class="cred-body">
                <div class="field" style="flex: 2;">
                    <div class="field-label">Username</div>
                    <div class="field-value">
                        <span>${escapeHtml(cred.username)}</span>
                    </div>
                </div>
                <div class="field" style="flex: 1;">
                    <div class="field-label">Password</div>
                    <div class="field-value">
                        <span class="password-dots">••••••••</span>
                    </div>
                </div>
            </div>
            <div class="btn-row">
                <button class="copy-btn" data-username="${escapeHtml(cred.username)}" data-action="copy-username">
                    📋 Copy Username
                </button>
                <button class="copy-btn" data-cred-id="${cred.id}" data-action="copy-password">
                    🔒 Copy Password
                </button>
            </div>
            ${cred.notes ? `<div class="notes-text">📝 ${escapeHtml(cred.notes)}</div>` : ''}
        </div>
    `).join('');

    // Attach event listeners
    container.querySelectorAll('[data-action="copy-username"]').forEach(btn => {
        btn.addEventListener('click', () => copyUsername(btn, btn.getAttribute('data-username')));
    });
    container.querySelectorAll('[data-action="copy-password"]').forEach(btn => {
        btn.addEventListener('click', () => copyPassword(btn, parseInt(btn.getAttribute('data-cred-id'))));
    });
}

// ==================== My Saved Credentials ====================

async function loadMyCredentials() {
    const myList = document.getElementById('myCredentialsList');
    const myLoading = document.getElementById('myLoading');
    myLoading.style.display = 'block';
    myList.innerHTML = '';

    try {
        const response = await fetch(
            `${SERVER_URL}/api/credentials/my?deviceId=${encodeURIComponent(deviceId)}`,
            { headers: { "X-API-KEY": API_KEY } }
        );

        myLoading.style.display = 'none';

        if (!response.ok) {
            myList.innerHTML = '<div class="no-results">Failed to load saved credentials.</div>';
            return;
        }

        myCredentials = await response.json();

        if (myCredentials.length === 0) {
            myList.innerHTML = `
                <div class="empty-state">
                    <div class="icon">💾</div>
                    <p><strong>No saved credentials yet</strong></p>
                    <p style="font-size: 0.85em; margin-top: 5px;">
                        Use the form above to save a password.
                    </p>
                </div>
            `;
            return;
        }

        renderMyCredentials(myCredentials);
    } catch (err) {
        myLoading.style.display = 'none';
        myList.innerHTML = '<div class="no-results">Cannot connect to server.</div>';
    }
}

function renderMyCredentials(credentials) {
    const container = document.getElementById('myCredentialsList');
    container.innerHTML = credentials.map(cred => `
        <div class="credential-card">
            <div class="cred-header">
                <div>
                    <div class="site-name">${escapeHtml(cred.siteName)}</div>
                    <a href="${escapeHtml(cred.siteUrl)}" target="_blank" class="site-url">${escapeHtml(cred.siteUrl)}</a>
                </div>
                <button class="delete-btn" data-cred-id="${cred.id}" data-action="delete-my">🗑 Delete</button>
            </div>
            <div class="cred-body">
                <div class="field" style="flex: 2;">
                    <div class="field-label">Username</div>
                    <div class="field-value">
                        <span>${escapeHtml(cred.username)}</span>
                    </div>
                </div>
                <div class="field" style="flex: 1;">
                    <div class="field-label">Password</div>
                    <div class="field-value">
                        <span class="password-dots">••••••••</span>
                    </div>
                </div>
            </div>
            <div class="btn-row">
                <button class="copy-btn" data-username="${escapeHtml(cred.username)}" data-action="copy-username">
                    📋 Copy Username
                </button>
                <button class="copy-btn" data-cred-id="${cred.id}" data-action="copy-password">
                    🔒 Copy Password
                </button>
            </div>
            ${cred.notes ? `<div class="notes-text">📝 ${escapeHtml(cred.notes)}</div>` : ''}
        </div>
    `).join('');

    // Attach event listeners
    container.querySelectorAll('[data-action="copy-username"]').forEach(btn => {
        btn.addEventListener('click', () => copyUsername(btn, btn.getAttribute('data-username')));
    });
    container.querySelectorAll('[data-action="copy-password"]').forEach(btn => {
        btn.addEventListener('click', () => copyPassword(btn, parseInt(btn.getAttribute('data-cred-id'))));
    });
    container.querySelectorAll('[data-action="delete-my"]').forEach(btn => {
        btn.addEventListener('click', () => deleteMyCredential(btn, parseInt(btn.getAttribute('data-cred-id'))));
    });
}

async function submitCredential() {
    const siteName = document.getElementById('saveSiteName').value.trim();
    const siteUrl = document.getElementById('saveSiteUrl').value.trim();
    const username = document.getElementById('saveUsername').value.trim();
    const password = document.getElementById('savePassword').value;
    const notes = document.getElementById('saveNotes').value.trim();

    if (!siteName || !siteUrl || !username || !password) {
        showToast("⚠️ Please fill in all required fields.");
        return;
    }

    const btn = document.getElementById('saveCredBtn');
    btn.disabled = true;
    btn.textContent = '⏳ Saving...';

    try {
        const response = await fetch(`${SERVER_URL}/api/credentials`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-API-KEY': API_KEY
            },
            body: JSON.stringify({ deviceId, siteName, siteUrl, username, password, notes })
        });

        if (!response.ok) {
            const errText = await response.text();
            throw new Error(errText || `Server error: ${response.status}`);
        }

        // Clear form
        document.getElementById('saveSiteName').value = '';
        document.getElementById('saveSiteUrl').value = '';
        document.getElementById('saveUsername').value = '';
        document.getElementById('savePassword').value = '';
        document.getElementById('saveNotes').value = '';

        showToast("✅ Credential saved successfully!");
        await loadMyCredentials();
    } catch (err) {
        showToast("❌ Failed to save: " + err.message);
    } finally {
        btn.disabled = false;
        btn.textContent = '💾 Save Credential';
    }
}

async function deleteMyCredential(btn, credentialId) {
    if (!confirm('Delete this credential?')) return;

    btn.disabled = true;
    btn.textContent = '⏳...';

    try {
        const response = await fetch(
            `${SERVER_URL}/api/credentials/${credentialId}?deviceId=${encodeURIComponent(deviceId)}`,
            { method: 'DELETE', headers: { 'X-API-KEY': API_KEY } }
        );

        if (response.ok) {
            showToast("🗑 Credential deleted.");
            await loadMyCredentials();
        } else {
            showToast("⚠️ Cannot delete: access denied.");
            btn.disabled = false;
            btn.textContent = '🗑 Delete';
        }
    } catch (err) {
        showToast("❌ Delete failed: " + err.message);
        btn.disabled = false;
        btn.textContent = '🗑 Delete';
    }
}

// ==================== Copy Helpers ====================

async function copyUsername(btn, username) {
    try {
        await navigator.clipboard.writeText(username);
        showCopied(btn, "✓ Username Copied!");
        showToast("Username copied to clipboard!");
    } catch (err) {
        showToast("Failed to copy: " + err.message);
    }
}

async function copyPassword(btn, credentialId) {
    btn.disabled = true;
    btn.textContent = "⏳ Fetching...";

    try {
        const response = await fetch(
            `${SERVER_URL}/api/credentials/${credentialId}/copy?deviceId=${encodeURIComponent(deviceId)}`,
            { headers: { "X-API-KEY": API_KEY } }
        );

        if (response.status === 403) {
            showToast("⚠️ Access denied to this credential.");
            btn.disabled = false;
            btn.textContent = "🔒 Copy Password";
            return;
        }

        if (!response.ok) {
            throw new Error(`Server error: ${response.status}`);
        }

        const data = await response.json();
        await navigator.clipboard.writeText(data.password);

        showCopied(btn, "✓ Password Copied!");
        showToast("🔒 Password copied to clipboard!");

        // Auto-clear clipboard after 30 seconds
        setTimeout(async () => {
            try {
                await navigator.clipboard.writeText("");
            } catch (e) { /* ignore */ }
        }, 30000);
    } catch (err) {
        showToast("Failed to copy password: " + err.message);
        btn.disabled = false;
        btn.textContent = "🔒 Copy Password";
    }
}

function showCopied(btn, text) {
    btn.classList.add('copied');
    btn.textContent = text;
    btn.disabled = false;
    setTimeout(() => {
        btn.textContent = btn.getAttribute('data-action') === 'copy-username' ? '📋 Copy Username' : '🔒 Copy Password';
        btn.classList.remove('copied');
    }, 2000);
}

// ==================== Utility ====================

function showToast(message) {
    const toast = document.getElementById('toast');
    toast.textContent = message;
    toast.classList.add('show');
    setTimeout(() => toast.classList.remove('show'), 2500);
}

function showError(message) {
    document.getElementById('loading').style.display = 'none';
    const errorEl = document.getElementById('errorState');
    errorEl.style.display = 'block';
    errorEl.textContent = message;
}

function escapeHtml(str) {
    if (!str) return '';
    return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

init();
