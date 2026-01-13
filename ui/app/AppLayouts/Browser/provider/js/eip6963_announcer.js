"use strict";

// EIP-6963: Multi Injected Provider Discovery
// https://eips.ethereum.org/EIPS/eip-6963
// This script announces the Status provider so dApps can discover it

(function() {
    const STATUS_PROVIDER_INFO = {
        uuid: "c14d6a7e-14c2-477d-bcb7-ffb732145eae",
        name: "Status",
        icon: "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzIiIGhlaWdodD0iMzIiIHZpZXdCb3g9IjAgMCAzMiAzMiIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4gPGcgY2xpcC1wYXRoPSJ1cmwoI2NsaXAwXzk1MF8xMjM5NikiPiA8bWFzayBpZD0ibWFzazBfOTUwXzEyMzk2IiBzdHlsZT0ibWFzay10eXBlOmFscGhhIiBtYXNrVW5pdHM9InVzZXJTcGFjZU9uVXNlIiB4PSIwIiB5PSItMSIgd2lkdGg9IjMyIiBoZWlnaHQ9IjMzIj4gPHBhdGggZD0iTTE2IC0wLjAwMDQ4ODI4MUM0IC0wLjAwMDQ4ODI4MSAwIDMuOTk5NTEgMCAxNS45OTk1QzAgMjcuOTk5NSA0IDMxLjk5OTUgMTYgMzEuOTk5NUMyOCAzMS45OTk1IDMyIDI3Ljk5OTUgMzIgMTUuOTk5NUMzMiAzLjk5OTUxIDI4IC0wLjAwMDQ4ODI4MSAxNiAtMC4wMDA0ODgyODFaIiBmaWxsPSJ3aGl0ZSIvPiA8L21hc2s+IDxnIG1hc2s9InVybCgjbWFzazBfOTUwXzEyMzk2KSI+IDxnIGZpbHRlcj0idXJsKCNmaWx0ZXIwX2ZfOTUwXzEyMzk2KSI+IDxjaXJjbGUgY3g9IjIzIiBjeT0iOC45OTk1MSIgcj0iMTkiIGZpbGw9IiMxOTkyRDciLz4gPC9nPiA8ZyBmaWx0ZXI9InVybCgjZmlsdGVyMV9mXzk1MF8xMjM5NikiPiA8Y2lyY2xlIGN4PSIzMyIgY3k9IjE4Ljk5OTUiIHI9IjE5IiBmaWxsPSIjRjZCMDNDIi8+IDwvZz4gPGcgZmlsdGVyPSJ1cmwoI2ZpbHRlcjJfZl85NTBfMTIzOTYpIj4gPGNpcmNsZSBjeD0iNSIgY3k9IjMwLjk5OTUiIHI9IjE5IiBmaWxsPSIjRkY3RDQ2Ii8+IDwvZz4gPGcgZmlsdGVyPSJ1cmwoI2ZpbHRlcjNfZl85NTBfMTIzOTYpIj4gPGNpcmNsZSBjeD0iLTciIGN5PSI4Ljk5OTUxIiByPSIxOSIgZmlsbD0iIzcxNDBGRCIvPiA8L2c+IDxwYXRoIGZpbGwtcnVsZT0iZXZlbm9kZCIgY2xpcC1ydWxlPSJldmVub2RkIiBkPSJNMTguMTI4NCA4LjgwODQzQzE0Ljk1NTEgOC45ODk4NCAxMi42MTIxIDExLjg3NDMgMTIuMzUxNiAxNS4xMzc1QzEyLjM2NzYgMTUuMTMyNiAxMi4zODUzIDE1LjEyNzYgMTIuNDAzIDE1LjEyMjdDMTIuNDIwNyAxNS4xMTc4IDEyLjQzODQgMTUuMTEyOSAxMi40NTQ0IDE1LjEwOEMxMi44NTM1IDE1LjAwNjcgMTMuMjYxNyAxNC45NDUyIDEzLjY3MzEgMTQuOTI0M0MxNC41NjQxIDE0Ljg3NDUgMTUuMjg4NyAxNC45NTE2IDE2LjAxMzIgMTUuMDI4OEMxNi43Mzg3IDE1LjEwNiAxNy40NjQgMTUuMTgzMiAxOC4zNTYyIDE1LjEzMjlDMTguNzY1OCAxNS4xMTEzIDE5LjE3MjIgMTUuMDQ3OSAxOS41Njg4IDE0Ljk0NEMyMS4yNDc2IDE0LjUwODYgMjIuMjEzNSAxMy4zNzQgMjIuMTI4MiAxMS44MTkxQzIyLjAyMzEgOS44ODcwOCAyMC4wNzY5IDguNjk3MzIgMTguMTI4NCA4LjgwODQzWk0xMy44Nzk2IDIzLjE5MDlDMTcuMDUyOSAyMy4wMDk1IDE5LjM5NTkgMjAuMTI1IDE5LjY1NjQgMTYuODYxOEMxOS42MzYzIDE2Ljg2OCAxOS42MTM1IDE2Ljg3NDIgMTkuNTkxNSAxNi44ODAxQzE5LjU3ODQgMTYuODgzNyAxOS41NjU1IDE2Ljg4NzIgMTkuNTUzNiAxNi44OTA1QzE5LjE1NDUgMTYuOTkxOSAxOC43NDYyIDE3LjA1MzQgMTguMzM0OCAxNy4wNzQyQzE3LjQ0MjcgMTcuMTI0OSAxNi43MTczIDE3LjA0NzkgMTUuOTkxOSAxNi45NzA4QzE1LjI2NzQgMTYuODkzOCAxNC41NDI4IDE2LjgxNjkgMTMuNjUxOCAxNi44NjcxQzEzLjI0MjEgMTYuODg4OCAxMi44MzU4IDE2Ljk1MjEgMTIuNDM5MiAxNy4wNTYxQzEwLjc2MDMgMTcuNDkwNyA5Ljc5ODI5IDE4LjYyNTMgOS44Nzk3OSAyMC4xODAyQzkuOTg0OTEgMjIuMTEyMiAxMS45MzExIDIzLjMwMiAxMy44Nzk2IDIzLjE5MDlaIiBmaWxsPSJ3aGl0ZSIvPiA8L2c+IDwvZz4gPGRlZnM+IDxmaWx0ZXIgaWQ9ImZpbHRlcjBfZl85NTBfMTIzOTYiIHg9Ii01LjQzMDI2IiB5PSItMTkuNDMwNyIgd2lkdGg9IjU2Ljg2MDUiIGhlaWdodD0iNTYuODYwNSIgZmlsdGVyVW5pdHM9InVzZXJTcGFjZU9uVXNlIiBjb2xvci1pbnRlcnBvbGF0aW9uLWZpbHRlcnM9InNSR0IiPiA8ZmVGbG9vZCBmbG9vZC1vcGFjaXR5PSIwIiByZXN1bHQ9IkJhY2tncm91bmRJbWFnZUZpeCIvPiA8ZmVCbGVuZCBtb2RlPSJub3JtYWwiIGluPSJTb3VyY2VHcmFwaGljIiBpbjI9IkJhY2tncm91bmRJbWFnZUZpeCIgcmVzdWx0PSJzaGFwZSIvPiA8ZmVHYXVzc2lhbkJsdXIgc3RkRGV2aWF0aW9uPSI0LjcxNTEzIiByZXN1bHQ9ImVmZmVjdDFfZm9yZWdyb3VuZEJsdXJfOTUwXzEyMzk2Ii8+IDwvZmlsdGVyPiA8ZmlsdGVyIGlkPSJmaWx0ZXIxX2ZfOTUwXzEyMzk2IiB4PSI0LjU2OTc0IiB5PSItOS40MzA3NSIgd2lkdGg9IjU2Ljg2MDUiIGhlaWdodD0iNTYuODYwNSIgZmlsdGVyVW5pdHM9InVzZXJTcGFjZU9uVXNlIiBjb2xvci1pbnRlcnBvbGF0aW9uLWZpbHRlcnM9InNSR0IiPiA8ZmVGbG9vZCBmbG9vZC1vcGFjaXR5PSIwIiByZXN1bHQ9IkJhY2tncm91bmRJbWFnZUZpeCIvPiA8ZmVCbGVuZCBtb2RlPSJub3JtYWwiIGluPSJTb3VyY2VHcmFwaGljIiBpbjI9IkJhY2tncm91bmRJbWFnZUZpeCIgcmVzdWx0PSJzaGFwZSIvPiA8ZmVHYXVzc2lhbkJsdXIgc3RkRGV2aWF0aW9uPSI0LjcxNTEzIiByZXN1bHQ9ImVmZmVjdDFfZm9yZWdyb3VuZEJsdXJfOTUwXzEyMzk2Ii8+IDwvZmlsdGVyPiA8ZmlsdGVyIGlkPSJmaWx0ZXIyX2ZfOTUwXzEyMzk2IiB4PSItMjMuNDMwMyIgeT0iMi41NjkyNSIgd2lkdGg9IjU2Ljg2MDUiIGhlaWdodD0iNTYuODYwNSIgZmlsdGVyVW5pdHM9InVzZXJTcGFjZU9uVXNlIiBjb2xvci1pbnRlcnBvbGF0aW9uLWZpbHRlcnM9InNSR0IiPiA8ZmVGbG9vZCBmbG9vZC1vcGFjaXR5PSIwIiByZXN1bHQ9IkJhY2tncm91bmRJbWFnZUZpeCIvPiA8ZmVCbGVuZCBtb2RlPSJub3JtYWwiIGluPSJTb3VyY2VHcmFwaGljIiBpbjI9IkJhY2tncm91bmRJbWFnZUZpeCIgcmVzdWx0PSJzaGFwZSIvPiA8ZmVHYXVzc2lhbkJsdXIgc3RkRGV2aWF0aW9uPSI0LjcxNTEzIiByZXN1bHQ9ImVmZmVjdDFfZm9yZWdyb3VuZEJsdXJfOTUwXzEyMzk2Ii8+IDwvZmlsdGVyPiA8ZmlsdGVyIGlkPSJmaWx0ZXIzX2ZfOTUwXzEyMzk2IiB4PSItMzUuNDMwMyIgeT0iLTE5LjQzMDciIHdpZHRoPSI1Ni44NjA1IiBoZWlnaHQ9IjU2Ljg2MDUiIGZpbHRlclVuaXRzPSJ1c2VyU3BhY2VPblVzZSIgY29sb3ItaW50ZXJwb2xhdGlvbi1maWx0ZXJzPSJzUkdCIj4gPGZlRmxvb2QgZmxvb2Qtb3BhY2l0eT0iMCIgcmVzdWx0PSJCYWNrZ3JvdW5kSW1hZ2VGaXgiLz4gPGZlQmxlbmQgbW9kZT0ibm9ybWFsIiBpbj0iU291cmNlR3JhcGhpYyIgaW4yPSJCYWNrZ3JvdW5kSW1hZ2VGaXgiIHJlc3VsdD0ic2hhcGUiLz4gPGZlR2F1c3NpYW5CbHVyIHN0ZERldmlhdGlvbj0iNC43MTUxMyIgcmVzdWx0PSJlZmZlY3QxX2ZvcmVncm91bmRCbHVyXzk1MF8xMjM5NiIvPiA8L2ZpbHRlcj4gPGNsaXBQYXRoIGlkPSJjbGlwMF85NTBfMTIzOTYiPiA8cmVjdCB3aWR0aD0iMzIiIGhlaWdodD0iMzIiIGZpbGw9IndoaXRlIi8+IDwvY2xpcFBhdGg+IDwvZGVmcz4gPC9zdmc+",
        rdns: "app.status"
    };
    
    function announceProvider(retries, announced) {
        // Wait for window.ethereum to be available (injected by ethereum_wrapper.js)
        if (!window.ethereum) {
            retries && setTimeout(announceProvider, 100, retries - 1, announced);
            return;
        }
        
        // Prevent double announcement
        if (announced) {
            return;
        }
        
        const detail = Object.freeze({
            info: STATUS_PROVIDER_INFO,
            provider: window.ethereum
        });
        
        window.dispatchEvent(
            new CustomEvent('eip6963:announceProvider', { detail })
        );
        
        console.log('[EIP-6963] Status provider announced');
        return true;
    }
    
    // Listen for discovery requests from dApps
    window.addEventListener('eip6963:requestProvider', function() {
        console.log('[EIP-6963] Provider discovery requested');
        announceProvider(50);
    });
    
    // Announce provider when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function() { announceProvider(50); });
    } else {
        // DOM already loaded, announce immediately (after ethereum is injected)
        setTimeout(function() { announceProvider(50); }, 0);
    }
    
})();
