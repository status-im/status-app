import QtQuick
import QtWebEngine

import StatusQ.Core.Theme

import "ScriptUtils.js" as ScriptUtils

WebEngineView {
    id: root

    property var currentWebView
    property bool enableJsLogs: false
    property bool htmlPageLoaded: false

    signal showFindBar(int numberOfMatches, int activeMatch)
    signal resetFindBar()

    focus: true

    function changeZoomFactor(newFactor) {
        zoomFactor = newFactor
    }

    backgroundColor: Theme.palette.background

    settings.autoLoadImages: localAccountSensitiveSettings.autoLoadImages
    settings.javascriptEnabled: localAccountSensitiveSettings.javaScriptEnabled
    settings.errorPageEnabled: localAccountSensitiveSettings.errorPageEnabled
    settings.pluginsEnabled: localAccountSensitiveSettings.pluginsEnabled
    settings.autoLoadIconsForPage: localAccountSensitiveSettings.autoLoadIconsForPage
    settings.touchIconsEnabled: localAccountSensitiveSettings.touchIconsEnabled
    settings.webRTCPublicInterfacesOnly: localAccountSensitiveSettings.webRTCPublicInterfacesOnly
    settings.pdfViewerEnabled: localAccountSensitiveSettings.pdfViewerEnabled
    settings.focusOnNavigationEnabled: true
    settings.forceDarkMode: Application.styleHints.colorScheme === Qt.ColorScheme.Dark

    onQuotaRequested: function(request) {
        if (request.requestedSize <= 5 * 1024 * 1024)
            request.accept();
        else
            request.reject();
    }

    onRegisterProtocolHandlerRequested: function(request) {
        console.log("accepting registerProtocolHandler request for "
                    + request.scheme + " from " + request.origin);
        request.accept();
    }

    onRenderProcessTerminated: function(terminationStatus, exitCode) {
        var status = "";
        switch (terminationStatus) {
        case WebEngineView.NormalTerminationStatus:
            status = "(normal exit)";
            break;
        case WebEngineView.AbnormalTerminationStatus:
            status = "(abnormal exit)";
            break;
        case WebEngineView.CrashedTerminationStatus:
            status = "(crashed)";
            break;
        case WebEngineView.KilledTerminationStatus:
            status = "(killed)";
            break;
        }

        console.warn("Render process exited with code " + exitCode + " " + status);
    }

    onSelectClientCertificate: function(selection) {
        selection.certificates[0].select();
    }

    onFindTextFinished: function(result) {
        root.showFindBar(result.numberOfMatches, result.activeMatch)
    }

    onLoadingChanged: function(loadRequest) {
        if (loadRequest.status === WebEngineView.LoadStartedStatus) {
            root.htmlPageLoaded = false
            root.resetFindBar()
        }
        if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
            root.htmlPageLoaded = true
        }
    }

    onLoadProgressChanged: function(progress) {
        if (progress >= 10) {
            // Some real content rendered
            htmlPageLoaded = true
        }
    }

    onNavigationRequested: function (request) {
        if(request.url.toString().startsWith("file:/")){
            console.log("Local file browsing is disabled" )
            request.reject()
        }
    }

    onJavaScriptConsoleMessage: function(level, message, lineNumber, sourceID) {
        // Check if the message is from our injected scripts
        const isOurScript = ScriptUtils.isOurInjectedScript(sourceID, root.profile);
        if (isOurScript || root.enableJsLogs) {
            console.log("[WebEngine]", sourceID + ":" + lineNumber, message);
        }
    }   
}
