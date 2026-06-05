// Status does not implement Chrome extensions. Prevent page access to the
// Chrome extension messaging API from causing crashes in QtWebEngine.
if (window.chrome && window.chrome.runtime) {
    window.chrome.runtime.sendMessage = undefined;
    window.chrome.runtime.connect = undefined;
}
