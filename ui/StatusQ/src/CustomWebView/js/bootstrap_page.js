// Page-side bootstrap (runs in pageWorld/default world, public)
// Creates a facade transport that communicates with bridgeWorld via DOM events
(function(ns) {
  'use strict';
  
  window[ns] = window[ns] || {};
  var _onmessage = null;
  
  // Queue for messages sent before bridge is ready
  var _pendingMessages = [];
  var _bridgeObserver = null;
  
  // Synchronous check for bridge readiness via DOM attribute
  // This is shared between content worlds and avoids race conditions
  function isBridgeReady() {
    return document.documentElement.dataset.sqBridgeReady === '1'; // see bootstrap_bridge.js
  }
  
  function flushPendingMessages() {
    while (_pendingMessages.length > 0) {
      var msg = _pendingMessages.shift();
      document.dispatchEvent(new CustomEvent('__sq_req__', { detail: msg }));
    }
  }
  
  // Wait for bridge to be ready using MutationObserver
  function waitForBridge(callback) {
    if (isBridgeReady()) {
      callback();
      return;
    }
    
    // Only create one observer
    if (_bridgeObserver) return;
    
    _bridgeObserver = new MutationObserver(function(mutations) {
      if (isBridgeReady()) {
        _bridgeObserver.disconnect();
        _bridgeObserver = null;
        callback();
      }
    });
    
    _bridgeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['data-sq-bridge-ready']
    });
  }
  
  // Create WebChannel transport facade
  window[ns].webChannelTransport = {
    send: function(msg) {
      if (isBridgeReady()) {
        // Send request to bridgeWorld via DOM event
        // see IsolatedWorldContext in webviewbackend.mm
        document.dispatchEvent(new CustomEvent('__sq_req__', { detail: msg }));
      } else {
        // Queue message until bridge is ready
        _pendingMessages.push(msg);
        waitForBridge(flushPendingMessages);
      }
    },
    set onmessage(fn) {
      _onmessage = fn;
    },
    get onmessage() {
      return _onmessage;
    }
  };
  
  // Called from native via evaluateJavaScript to deliver messages from Qt
  // (Kept for backward compatibility with non-isolated mode)
  // see PageWorldContext in webviewbackend.mm
  window[ns].__deliverMessage = function(data) {
    if (typeof _onmessage === 'function') {
      _onmessage({ data: data });
    }
  };
  
  // Listen for push messages from bridgeWorld
  document.addEventListener('__sq_push__', function(e) {
    if (typeof _onmessage === 'function') {
      _onmessage({ data: e.detail });
    }
  });
  
  // Signal that the WebChannel transport is ready
  // This allows other scripts (like ethereum_injector.js) to know when they can initialize
  window.dispatchEvent(new Event('qtWebChannelReady'));
})('%NS%');
