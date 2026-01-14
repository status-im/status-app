"use strict";

// IIFE start (https://developer.mozilla.org/ru/docs/Glossary/IIFE)
const EthereumWrapper = (function() {
    if (window.__ETHEREUM_WRAPPER_INSTANCE__) {
        return window.__ETHEREUM_WRAPPER_INSTANCE__;
    }
    
    // Manages EIP-1193 provider wrapper around Qml ethereum object (EIP1193ProviderAdapter.qml)
    class EthereumProvider extends EventTarget {
        constructor(nativeEthereum) {
            super();
            
            if (!nativeEthereum) {
                console.error("[Ethereum Wrapper] nativeEthereum is not available");
                throw new Error("nativeEthereum is required");
            }

            this.listeners = new Map(); // event -> Set<handler>
            this.nativeEthereum = nativeEthereum;
            this.requestIdCounter = 1; // async requests
            this.pendingRequests = new Map(); // requestId -> { resolve, reject, timestamp }
            this.requestTimeout = 600000; // 10min timeout for pending requests. (nim side has it's own timeouts)
            this.timeoutCheckInterval = 10000;
            
            // Wire native signals to events
            this._wireSignals();
            
            // Setup page unload handler
            this._setupPageUnloadHandler();
            this._startTimeoutChecker();
            
            // Set up EIP-1193 properties from QML
            this.isStatus = nativeEthereum.isStatus !== undefined ? nativeEthereum.isStatus : true;
            this.isMetaMask = nativeEthereum.isMetaMask !== undefined ? nativeEthereum.isMetaMask : false;
            this.chainId = null;  // Will be set on first eth_chainId request or providerStateChanged event
            this.networkVersion = null;  // decimal string format (deprecated)
            this.selectedAddress = null;  // current active address
            this._connected = false;
        }

        _connectSignal(eventName, handler) {
            const event = this.nativeEthereum[eventName];
            if (event && event.connect) {
                event.connect(handler);
                return true;
            }
            return false;
        }

        _rejectRequests(requestsToReject, deleteFromPending = false) {
            for (const [requestId, entry, error] of requestsToReject) {
                try {
                    entry.reject(error);
                } catch (e) {
                    console.error('[Ethereum Wrapper] Error rejecting request:', e);
                }
                if (deleteFromPending) {
                    this.pendingRequests.delete(requestId);
                }
            }
        }

        _rejectAllPendingRequests(error) {
            const requestsToReject = Array.from(this.pendingRequests.entries())
                .map(([requestId, entry]) => [requestId, entry, error]);
            this.pendingRequests.clear();
            this._rejectRequests(requestsToReject, false);
        }

        _checkTimedOutRequests() {
            const now = Date.now();
            const timedOutRequests = [];
            
            for (const [requestId, entry] of this.pendingRequests.entries()) {
                if (now - entry.timestamp > this.requestTimeout) {
                    timedOutRequests.push([
                        requestId, 
                        entry, 
                        {
                            code: -32603,
                            message: `Request timed out after ${this.requestTimeout}ms`
                        }
                    ]);
                }
            }
            
            if (timedOutRequests.length > 0) {
                console.warn('[Ethereum Wrapper] Found', timedOutRequests.length, 'timed out requests');
                this._rejectRequests(timedOutRequests, true);
            }
        }

        _startTimeoutChecker() {
            if (this.timeoutCheckIntervalId) {
                return;
            }
            
            this.timeoutCheckIntervalId = setInterval(() => {
                if (this.pendingRequests.size > 0) {
                    this._checkTimedOutRequests();
                }
            }, this.timeoutCheckInterval);
        }

        _stopTimeoutChecker() {
            if (this.timeoutCheckIntervalId) {
                clearInterval(this.timeoutCheckIntervalId);
                this.timeoutCheckIntervalId = null;
            }
        }

        _setupPageUnloadHandler() {
            window.addEventListener('beforeunload', () => {
                this._stopTimeoutChecker();
                this._rejectAllPendingRequests({
                    code: -32603,
                    message: 'Page is being unloaded'
                });
            });
        }

        _wireSignals() {
            this._connectSignal('connectEvent', (info) => {
                this._emit('connect', info);
            });

            this._connectSignal('disconnectEvent', (error) => {
                this._rejectAllPendingRequests({
                    code: 4900,
                    message: 'Provider disconnected'
                });
                
                this._emit('disconnect', error);
            });

            this._connectSignal('messageEvent', (message) => {
                this._emit('message', message);
            });

            this._connectSignal('chainChangedEvent', (chainId) => {
                this._emit('chainChanged', chainId);
            });

            this._connectSignal('accountsChangedEvent', (accounts) => {
                this._emit('accountsChanged', accounts);
            });

            // Provider state changed - update all properties at once
            this._connectSignal('providerStateChanged', () => {
                this.isStatus = this.nativeEthereum.isStatus !== undefined ? this.nativeEthereum.isStatus : this.isStatus;
                this.isMetaMask = this.nativeEthereum.isMetaMask !== undefined ? this.nativeEthereum.isMetaMask : this.isMetaMask;
                this.chainId = this.nativeEthereum.chainId || this.chainId;
                this.networkVersion = this.nativeEthereum.networkVersion || this.networkVersion;
                this.selectedAddress = this.nativeEthereum.selectedAddress || null;
                this._connected = this.nativeEthereum.connected !== undefined ? this.nativeEthereum.connected : this._connected;
            });

            // Handle async RPC responses
            this._connectSignal('requestCompletedEvent', this.handleRequestCompleted.bind(this));
        }

        _emit(event, ...args) {
            const set = this.listeners.get(event);
            if (!set) return;
            for (const handler of set) {
                try { 
                    handler(...args); 
                } catch (e) { 
                    console.error("[Ethereum Wrapper] handler error", e); 
                }
            }
        }

        isConnected() {
            return this._connected;
        }

        request(args) {
            if (!args || typeof args !== 'object' || !args.method) {
                return Promise.reject({
                    code: -32602,
                    message: 'Invalid params: missing method'
                });
            }
            const requestId = this.requestIdCounter++;
            const payload = Object.assign({}, args, { requestId });
            
            return new Promise((resolve, reject) => {
                this.pendingRequests.set(requestId, { 
                    resolve, 
                    reject, 
                    method: args.method,
                    timestamp: Date.now()
                });
                
                try {
                    const nativeResp = this.nativeEthereum.request(payload);
                    
                    if (nativeResp && typeof nativeResp === 'string') {
                        try {
                            const parsedResp = JSON.parse(nativeResp);
                            if (parsedResp?.error) {
                                this.pendingRequests.delete(requestId);
                                reject(parsedResp.error);
                                return;
                            }
                        } catch {}
                    }
                } catch (e) {
                    // Only catch synchronous exceptions (e.g., invalid payload)
                    this.pendingRequests.delete(requestId);
                    reject(e);
                }
            });
        }

        // Method for backward compatibility with older dApps
        enable() {
            return this.request({ method: 'eth_requestAccounts' });
        }

        _processResponse(resp, method, entry) {
            if (resp && typeof resp === 'string') {
                try {
                    const parsed = JSON.parse(resp);
                    resp = parsed;
                } catch (e) {
                    entry.resolve(resp);
                    return;
                }
            }
            
            if (resp && resp.error) {
                entry.reject(resp.error);
            } else if (resp && resp.result !== undefined) {
                entry.resolve(resp.result);
            } else {
                entry.resolve(resp);
            }
        }

        handleRequestCompleted(payload) {
            const requestId = payload && (payload.requestId || (payload.response && payload.response.id)) || 0;
            try {
                const entry = this.pendingRequests.get(requestId);
                
                if (!entry) {
                    console.warn("[Ethereum Wrapper] No pending request found for ID:", requestId);
                    return;
                }
                
                this._processResponse(payload && payload.response, entry.method, entry);
            } catch (e) {
                console.error('[Ethereum Wrapper] requestCompletedEvent handler error', e);
            } finally {
                if (requestId) {
                    this.pendingRequests.delete(requestId);
                }
            }
        }

        on(event, handler) {
            if (typeof handler !== 'function') return this;
            const set = this.listeners.get(event) || new Set();
            set.add(handler);
            this.listeners.set(event, set);
            return this;
        }

        once(event, handler) {
            if (typeof handler !== 'function') return this;
            const self = this;
            function onceHandler() {
                try { 
                    handler.apply(null, arguments); 
                } finally {
                    self.removeListener(event, onceHandler);
                }
            }
            return this.on(event, onceHandler);
        }

        removeListener(event, handler) {
            const set = this.listeners.get(event);
            if (!set) return this;
            set.delete(handler);
            if (set.size === 0) this.listeners.delete(event);
            return this;
        }

        removeAllListeners(event) {
            if (event) {
                this.listeners.delete(event);
            } else {
                this.listeners.clear();
            }
            return this;
        }

        // Deprecated aliases for compatibility
        addListener(event, handler) { 
            return this.on(event, handler); 
        }
        
        off(event, handler) { 
            return this.removeListener(event, handler); 
        }
    }

    function install() {
        if (window.__ETHEREUM_INSTALLED__) {
            return true;
        }
        
        if (!window.ethereumProvider) {
            return false;
        }
        
        let provider;
        try {
            provider = new EthereumProvider(window.ethereumProvider);
        } catch (error) {
            console.error('[Ethereum Wrapper] Failed to create EthereumProvider:', error);
            return false;
        }

        if (!window.ethereum) {
            Object.defineProperty(window, 'ethereum', {
                value: provider,
                writable: false,
                configurable: false,
                enumerable: true
            });
            window.__ETHEREUM_INSTALLED__ = true;
            window.dispatchEvent(new Event('ethereum#initialized'));
            return true;
        } else {
            console.warn('[Ethereum Wrapper] window.ethereum already present; skipping install');
            return false;
        }
    }
    
    // Return public API if needed
    const instance = {
        EthereumProvider: EthereumProvider,
        install: install
    };
    
    // Store instance globally to prevent duplicate loading
    window.__ETHEREUM_WRAPPER_INSTANCE__ = instance;
    
    return instance;

})(); // IIFE end
