const API_KEY = "productivity-secret-key-2024";
let deviceId = null;
let allCredentials = [];

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
    } catch (err) {
        showError("Failed to read configuration: " + err.message);
    }
}

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

