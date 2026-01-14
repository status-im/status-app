// Bridge-side bootstrap (runs in bridgeWorld/StatusBridge isolated(!) world)
// Listens to DOM events from pageWorld and forwards to native handler
(function(invokeKey) {
  'use strict';
  
  // Test if webkit.messageHandlers is available
  var handlerAvailable = typeof webkit !== 'undefined' && 
                         webkit.messageHandlers && 
                         webkit.messageHandlers.qtbridge;
  
  // Listen for requests from pageWorld via DOM events
  // Note: DOM events are shared between content worlds
  document.addEventListener('__sq_req__', function(e) {
    var packet = JSON.stringify({
      invokeKey: invokeKey,
      data: String(e.detail)
    });
    
    if (handlerAvailable) {
      webkit.messageHandlers.qtbridge.postMessage(packet);
    } else {
      console.error('[QtBridge/bridge] Message handler not available');
    }
  });
  
  // Signal to pageWorld that bridge is ready to receive messages
  // Using DOM attribute instead of event to avoid race conditions between content worlds
  document.documentElement.dataset.sqBridgeReady = '1';
  
  console.log('[QtBridge/bridge] Listener ready, handler available:', handlerAvailable);
})('%INVOKE_KEY%');
