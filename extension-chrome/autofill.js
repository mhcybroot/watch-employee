// Auto-fill content script — injected into all web pages
(function () {
    'use strict';

    // Prevent double-injection
    if (window.__watcherAutofillInjected) return;
    window.__watcherAutofillInjected = true;

    let currentBanner = null;
    let matchedCredentials = [];
    let selectedIndex = 0;

    // ========== Form Detection ==========

    function findPasswordFields() {
        return document.querySelectorAll('input[type="password"]:not([aria-hidden="true"]):not([hidden])');
    }

    function findUsernameField(passwordField) {
        const form = passwordField.closest('form');
        const scope = form || document;

        // Priority order for username field detection
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

    // ========== Banner UI ==========

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
            // Single credential
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
            // Multiple credentials — show dropdown
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

        // Event listeners
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

        // Insert banner before the form or password field
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
            // Request password from background
            const runtime = typeof browser !== 'undefined' ? browser.runtime : chrome.runtime;
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
                // Fill username
                const usernameField = findUsernameField(passwordField);
                if (usernameField) {
                    setNativeValue(usernameField, cred.username);
                }

                // Fill password
                setNativeValue(passwordField, response.password);

                showSuccess();
            }
        } catch (err) {
            console.error('[WatcherAutoFill] Fill error:', err);
            if (fillBtn) { fillBtn.textContent = '▶ Fill'; fillBtn.disabled = false; }
        }
    }

    // Set value using native input setter to trigger React/Angular/Vue change detection
    function setNativeValue(element, value) {
        const nativeInputValueSetter = Object.getOwnPropertyDescriptor(
            window.HTMLInputElement.prototype, 'value'
        ).set;
        nativeInputValueSetter.call(element, value);
        element.dispatchEvent(new Event('input', { bubbles: true }));
        element.dispatchEvent(new Event('change', { bubbles: true }));
    }

    // ========== Main Scan ==========

    async function scanForForms() {
        const passwordFields = findPasswordFields();
        if (passwordFields.length === 0) return;

        // Already showing a banner
        if (currentBanner) return;

        try {
            const runtime = typeof browser !== 'undefined' ? browser.runtime : chrome.runtime;
            const response = await runtime.sendMessage({
                type: 'check-autofill',
                url: window.location.href
            });

            if (response && response.credentials && response.credentials.length > 0) {
                // Filter credentials that match current page URL
                const matching = response.credentials.filter(c =>
                    urlMatches(c.siteUrl, window.location.href)
                );

                if (matching.length > 0) {
                    showBanner(matching, passwordFields[0]);
                }
            }
        } catch (err) {
            // Extension context may be invalid — silently ignore
            console.debug('[WatcherAutoFill] Scan skipped:', err.message);
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

    // Initial scan after page load
    setTimeout(scanForForms, 1000);

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
