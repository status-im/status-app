"use strict";

// Site utilities for Status Browser - clears origin-scoped storage.
// Injected as a user script so WebViewAdapter can trigger a per-origin clear
// via runJavaScript("window.StatusSiteUtils.clearSiteDataAndReload()").
// Desktop only: WebEngine has no honest per-site primitive (see mobilewebview
// ADR 0004); mobile uses the native clearSiteData() instead.
(function() {
    async function clearSiteData() {
        // Clear localStorage
        try { localStorage.clear(); } catch(e) {}

        // Clear sessionStorage
        try { sessionStorage.clear(); } catch(e) {}

        // Clear all IndexedDB databases
        if (indexedDB?.databases) {
            try {
                const dbs = await indexedDB.databases();
                await Promise.all(dbs.map(db => new Promise(resolve => {
                    const req = indexedDB.deleteDatabase(db.name);
                    req.onsuccess = req.onerror = req.onblocked = resolve;
                })));
            } catch(e) {}
        }

        // Clear Cache Storage (Service Worker caches)
        if (window.caches) {
            try {
                const cacheNames = await caches.keys();
                await Promise.all(cacheNames.map(name => caches.delete(name)));
            } catch(e) {}
        }

        // Unregister all Service Workers
        if (navigator.serviceWorker) {
            try {
                const registrations = await navigator.serviceWorker.getRegistrations();
                await Promise.all(registrations.map(reg => reg.unregister()));
            } catch(e) {}
        }

        // Clear cookies for current domain
        try {
            document.cookie.split(";").forEach(cookie => {
                const name = cookie.split("=")[0].trim();
                document.cookie = name + "=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/";
            });
        } catch(e) {}
    }

    async function clearSiteDataAndReload() {
        await clearSiteData();
        location.reload();
    }

    window.StatusSiteUtils = { clearSiteData, clearSiteDataAndReload };
})();
