"use strict";

// Ethereum Injector - Initializes QWebChannel and sets up the Ethereum provider
// This script handles the connection between the page and the Status wallet

function initializeWebChannel() {
    if (typeof qt !== 'undefined' && qt.webChannelTransport) {
        try {
            new QWebChannel(qt.webChannelTransport, setupEthereumProvider);
            return true;
        } catch (error) {
            console.error("[Ethereum Injector] Error initializing WebChannel:", error);
            return false;
        }
    }
    
    return false;
}

function setupEthereumProvider(channel) {
    window.ethereumProvider = channel.objects.ethereumProvider; // Eip1193ProviderAdapter.qml
    
    if (!window.ethereumProvider) {
        console.error("[Ethereum Injector] ethereumProvider not found in channel.objects");
        return;
    }

    // Install the EIP-1193 js wrapper with retry (script order not guaranteed)
    (function install(retries) {
        const installed = typeof EthereumWrapper !== 'undefined' && EthereumWrapper.install && EthereumWrapper.install();
        return installed || retries && setTimeout(install, 50, retries - 1);
    })(30);
}

// Retry mechanism with exponential backoff
// This handles the race condition where bootstrap_page.js may not have executed yet
(function retry(retries, initialized) {
    initialized = initialized || initializeWebChannel();
    initialized || retries && setTimeout(retry, 50 * Math.min(31 - retries, 5), retries - 1, initialized);
})(30);

// Also listen for the ready event from bootstrap_page.js
window.addEventListener('qtWebChannelReady', initializeWebChannel, { once: true });
