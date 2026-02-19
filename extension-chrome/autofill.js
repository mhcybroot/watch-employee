// Auto-fill content script — injected into all web pages
(function () {
    'use strict';

    // Prevent double-injection
    if (window.__watcherAutofillInjected) return;
    window.__watcherAutofillInjected = true;

    let currentBanner = null;
    let matchedCredentials = [];
    let selectedIndex = 0;
    let wasAutoFilled = false;       // Track if we just auto-filled
    let dismissedSaveUrls = new Set(); // Don't re-prompt same URL in this session

    const runtime = typeof browser !== 'undefined' ? browser.runtime : chrome.runtime;
    const storage = typeof browser !== 'undefined' ? browser.storage : chrome.storage;

    // ========== Form Detection ==========

    function findPasswordFields() {
        return document.querySelectorAll('input[type="password"]:not([aria-hidden="true"]):not([hidden])');
    }

    function findUsernameField(passwordField) {
        const form = passwordField.closest('form');
        const scope = form || document;

        const selectors = [
            'input[autocomplete="username"]',
            'input[autocomplete="email"]',
            'input[type="email"]',
            'input[name*="user" i]',
            'input[name*="email" i]',
            'input[name*="login" i]',
            'input[id*="user" i]',
            'input[id*="email" i]',
            'input[id*="login" i]',
            'input[type="text"]'
        ];

        for (const selector of selectors) {
            const fields = scope.querySelectorAll(selector);
            for (const field of fields) {
                if (field !== passwordField && isVisible(field)) {
                    return field;
                }
            }
        }
        return null;
    }

    function isVisible(el) {
        if (!el) return false;
        const style = window.getComputedStyle(el);
        return style.display !== 'none' && style.visibility !== 'hidden' && el.offsetParent !== null;
    }

    // ========== URL Matching ==========

    function urlMatches(credSiteUrl, pageUrl) {
        try {
            const credHost = new URL(credSiteUrl).hostname.replace(/^www\./, '');
            const pageHost = new URL(pageUrl).hostname.replace(/^www\./, '');
            return pageHost === credHost || pageHost.endsWith('.' + credHost);
        } catch {
            return false;
        }
    }

    // ========== Banner UI (Auto-Fill) ==========

    function removeBanner() {
        if (currentBanner && currentBanner.parentNode) {
            currentBanner.classList.add('watcher-fade-out');
            setTimeout(() => {
                if (currentBanner && currentBanner.parentNode) {
                    currentBanner.parentNode.removeChild(currentBanner);
                }
                currentBanner = null;
            }, 300);
        }
    }

    function showBanner(credentials, passwordField) {
        removeBanner();
        matchedCredentials = credentials;
        selectedIndex = 0;

        const banner = document.createElement('div');
        banner.className = 'watcher-autofill-banner';

        if (credentials.length === 1) {
            const cred = credentials[0];
            banner.innerHTML = `
                <div class="watcher-autofill-info">
                    <span class="watcher-autofill-icon">🔐</span>
                    <div>
                        <div class="watcher-autofill-site">${escapeHtml(cred.siteName)}</div>
                        <div class="watcher-autofill-user">${escapeHtml(cred.username)}</div>
                    </div>
                </div>
                <div class="watcher-autofill-actions">
                    <button class="watcher-autofill-fill-btn" data-action="fill">▶ Fill</button>
                    <button class="watcher-autofill-dismiss-btn" data-action="dismiss">✕</button>
                </div>
            `;
        } else {
            const options = credentials.map((c, i) =>
                `<option value="${i}">${escapeHtml(c.siteName)} — ${escapeHtml(c.username)}</option>`
            ).join('');
            banner.innerHTML = `
                <div class="watcher-autofill-info">
                    <span class="watcher-autofill-icon">🔐</span>
                    <div class="watcher-autofill-dropdown">
                        <select class="watcher-autofill-select" data-action="select">${options}</select>
                    </div>
                </div>
                <div class="watcher-autofill-actions">
                    <button class="watcher-autofill-fill-btn" data-action="fill">▶ Fill</button>
                    <button class="watcher-autofill-dismiss-btn" data-action="dismiss">✕</button>
                </div>
            `;
        }

        banner.addEventListener('click', (e) => {
            const action = e.target.getAttribute('data-action');
            if (action === 'fill') {
                fillCredential(passwordField);
            } else if (action === 'dismiss') {
                removeBanner();
            }
        });

        banner.addEventListener('change', (e) => {
            if (e.target.getAttribute('data-action') === 'select') {
                selectedIndex = parseInt(e.target.value);
            }
        });

        const form = passwordField.closest('form');
        const target = form || passwordField;
        if (target.parentNode) {
            target.parentNode.insertBefore(banner, target);
        }

        currentBanner = banner;
    }

    function showSuccess() {
        if (currentBanner) {
            currentBanner.classList.add('watcher-autofill-success');
            const info = currentBanner.querySelector('.watcher-autofill-info');
            const actions = currentBanner.querySelector('.watcher-autofill-actions');
            if (info) info.innerHTML = '<span class="watcher-autofill-icon">✅</span><div class="watcher-autofill-site">Filled successfully!</div>';
            if (actions) actions.innerHTML = '';
            setTimeout(removeBanner, 2000);
        }
    }

    // ========== Fill Logic ==========

    async function fillCredential(passwordField) {
        const cred = matchedCredentials[selectedIndex];
        if (!cred) return;

        const fillBtn = currentBanner && currentBanner.querySelector('.watcher-autofill-fill-btn');
        if (fillBtn) {
            fillBtn.textContent = '⏳ Filling...';
            fillBtn.disabled = true;
        }

        try {
            const response = await runtime.sendMessage({
                type: 'get-password',
                credentialId: cred.id
            });

            if (response && response.error) {
                if (fillBtn) fillBtn.textContent = '❌ ' + response.error;
                setTimeout(() => { if (fillBtn) fillBtn.textContent = '▶ Fill'; fillBtn.disabled = false; }, 2000);
                return;
            }

            if (response && response.password) {
                const usernameField = findUsernameField(passwordField);
                if (usernameField) {
                    setNativeValue(usernameField, cred.username);
                }
                setNativeValue(passwordField, response.password);

                wasAutoFilled = true; // Mark so we skip save prompt
                showSuccess();
            }
        } catch (err) {
            console.error('[WatcherAutoFill] Fill error:', err);
            if (fillBtn) { fillBtn.textContent = '▶ Fill'; fillBtn.disabled = false; }
        }
    }

    function setNativeValue(element, value) {
        const nativeInputValueSetter = Object.getOwnPropertyDescriptor(
            window.HTMLInputElement.prototype, 'value'
        ).set;
        nativeInputValueSetter.call(element, value);
        element.dispatchEvent(new Event('input', { bubbles: true }));
        element.dispatchEvent(new Event('change', { bubbles: true }));
    }

    // ========== Auto-Fill Scan ==========

    async function scanForForms() {
        const passwordFields = findPasswordFields();
        if (passwordFields.length === 0) return;

        if (currentBanner) return;

        try {
            const response = await runtime.sendMessage({
                type: 'check-autofill',
                url: window.location.href
            });

            if (response && response.credentials && response.credentials.length > 0) {
                const matching = response.credentials.filter(c =>
                    urlMatches(c.siteUrl, window.location.href)
                );

                if (matching.length > 0) {
                    showBanner(matching, passwordFields[0]);
                }
            }
        } catch (err) {
            console.debug('[WatcherAutoFill] Scan skipped:', err.message);
        }
    }

    // ========== Auto-Save on Form Submit ==========

    function setupFormSubmitListeners() {
        // Listen for all form submissions
        document.addEventListener('submit', handleFormSubmit, true);

        // Also listen for click on submit buttons (for AJAX forms)
        document.addEventListener('click', (e) => {
            const btn = e.target.closest('button[type="submit"], input[type="submit"]');
            if (btn) {
                const form = btn.closest('form');
                if (form) {
                    const pwField = form.querySelector('input[type="password"]');
                    if (pwField && pwField.value) {
                        captureAndPromptSave(form);
                    }
                }
            }
        }, true);
    }

    function handleFormSubmit(e) {
        const form = e.target;
        if (!(form instanceof HTMLFormElement)) return;

        const pwField = form.querySelector('input[type="password"]');
        if (!pwField || !pwField.value) return;

        // Skip if we just auto-filled this form
        if (wasAutoFilled) {
            wasAutoFilled = false;
            return;
        }

        const url = window.location.href;
        if (dismissedSaveUrls.has(url)) return;

        const usernameField = findUsernameField(pwField);
        const username = usernameField ? usernameField.value.trim() : '';
        const password = pwField.value;

        if (!username || !password) return;

        const hostname = window.location.hostname;
        const siteName = document.title || hostname;

        // Store pending credential for after navigation
        const pendingCred = {
            siteName: siteName,
            siteUrl: window.location.origin,
            username: username,
            password: password,
            capturedAt: Date.now()
        };

        // Try to save to extension storage for post-navigation prompt
        try {
            storage.local.set({ pendingCredential: pendingCred });
        } catch (err) {
            console.debug('[WatcherAutoSave] Storage error:', err);
        }

        // For AJAX forms (no navigation), show the save banner immediately
        // We use a small delay to check if the page navigated
        setTimeout(() => {
            // If we're still on the same page, show inline save prompt
            if (window.location.href === url) {
                showSaveBanner(pendingCred);
            }
        }, 1500);
    }

    function captureAndPromptSave(form) {
        const pwField = form.querySelector('input[type="password"]');
        if (!pwField || !pwField.value) return;

        if (wasAutoFilled) {
            wasAutoFilled = false;
            return;
        }

        const url = window.location.href;
        if (dismissedSaveUrls.has(url)) return;

        const usernameField = findUsernameField(pwField);
        const username = usernameField ? usernameField.value.trim() : '';
        const password = pwField.value;
        if (!username || !password) return;

        const pendingCred = {
            siteName: document.title || window.location.hostname,
            siteUrl: window.location.origin,
            username: username,
            password: password,
            capturedAt: Date.now()
        };

        try {
            storage.local.set({ pendingCredential: pendingCred });
        } catch (err) { /* ignore */ }
    }

    // ========== Save Banner UI ==========

    function showSaveBanner(cred) {
        removeBanner();

        const banner = document.createElement('div');
        banner.className = 'watcher-autofill-banner watcher-save-banner';
        banner.innerHTML = `
            <div class="watcher-autofill-info">
                <span class="watcher-autofill-icon">💾</span>
                <div>
                    <div class="watcher-autofill-site">Save password?</div>
                    <div class="watcher-autofill-user">${escapeHtml(cred.username)} on ${escapeHtml(cred.siteName)}</div>
                </div>
            </div>
            <div class="watcher-autofill-actions">
                <button class="watcher-autofill-fill-btn watcher-save-btn" data-action="save">💾 Save</button>
                <button class="watcher-autofill-dismiss-btn" data-action="dismiss-save">✕</button>
            </div>
        `;

        banner.addEventListener('click', async (e) => {
            const action = e.target.getAttribute('data-action');
            if (action === 'save') {
                await doSaveCredential(cred, e.target);
            } else if (action === 'dismiss-save') {
                dismissedSaveUrls.add(window.location.href);
                clearPendingCredential();
                removeBanner();
            }
        });

        // Insert at top of body
        document.body.insertBefore(banner, document.body.firstChild);
        currentBanner = banner;

        // Auto-dismiss after 15 seconds
        setTimeout(() => {
            if (currentBanner === banner) {
                removeBanner();
            }
        }, 15000);
    }

    async function doSaveCredential(cred, btn) {
        if (btn) {
            btn.textContent = '⏳ Saving...';
            btn.disabled = true;
        }

        try {
            const response = await runtime.sendMessage({
                type: 'save-credential',
                siteName: cred.siteName,
                siteUrl: cred.siteUrl,
                username: cred.username,
                password: cred.password
            });

            clearPendingCredential();

            if (response && response.success) {
                if (currentBanner) {
                    currentBanner.classList.remove('watcher-save-banner');
                    currentBanner.classList.add('watcher-autofill-success');
                    const info = currentBanner.querySelector('.watcher-autofill-info');
                    const actions = currentBanner.querySelector('.watcher-autofill-actions');
                    if (info) info.innerHTML = '<span class="watcher-autofill-icon">✅</span><div class="watcher-autofill-site">Credential saved!</div>';
                    if (actions) actions.innerHTML = '';
                    setTimeout(removeBanner, 2000);
                }
            } else {
                if (btn) {
                    btn.textContent = '❌ Failed';
                    setTimeout(() => { btn.textContent = '💾 Save'; btn.disabled = false; }, 2000);
                }
            }
        } catch (err) {
            console.error('[WatcherAutoSave] Save error:', err);
            if (btn) { btn.textContent = '💾 Save'; btn.disabled = false; }
        }
    }

    function clearPendingCredential() {
        try {
            storage.local.remove('pendingCredential');
        } catch (err) { /* ignore */ }
    }

    // ========== Check for Pending Credential (after navigation) ==========

    async function checkPendingCredential() {
        try {
            const data = await new Promise((resolve) => {
                if (typeof browser !== 'undefined') {
                    browser.storage.local.get(['pendingCredential']).then(resolve);
                } else {
                    chrome.storage.local.get(['pendingCredential'], resolve);
                }
            });

            if (data.pendingCredential) {
                const cred = data.pendingCredential;
                // Only show if captured within last 30 seconds
                if (Date.now() - cred.capturedAt < 30000) {
                    // Small delay to let the page render
                    setTimeout(() => showSaveBanner(cred), 800);
                } else {
                    clearPendingCredential();
                }
            }
        } catch (err) {
            console.debug('[WatcherAutoSave] Pending check error:', err);
        }
    }

    // ========== Helpers ==========

    function escapeHtml(str) {
        if (!str) return '';
        const div = document.createElement('div');
        div.textContent = str;
        return div.innerHTML;
    }

    // ========== Initialization ==========

    // Auto-fill scan
    setTimeout(scanForForms, 1000);

    // Form submit listeners for auto-save
    setupFormSubmitListeners();

    // Check for pending credential from previous page
    checkPendingCredential();

    // Re-scan on DOM mutations (for SPAs)
    const observer = new MutationObserver(() => {
        if (!currentBanner) {
            setTimeout(scanForForms, 500);
        }
    });

    observer.observe(document.body || document.documentElement, {
        childList: true,
        subtree: true
    });
})();
