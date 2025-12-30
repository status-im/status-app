import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme

import AppLayouts.Browser.popups

// TODO: Add WebView in this file for mobile platform
Item {
    id: root

    readonly property var currentView: webContainerLoader.item
    property var webChannel
    property var inspectedView
    property var currentWebViewProfile
    property bool isDebugEnabled
    property var fnCreateEmptyTab: (profile, createAsStartPage, focusOnNewTab, url) => {}

    property var downloadViewComponent
    property var emptyPageComponent
    property bool isDownloadView
    property bool isEmptyPage

    signal showFindBar(int numberOfMatches, int activeMatch)
    signal resetFindBar()
    signal removeView(int index)
    signal showSslDialog(var error)
    signal showJsDialogComponent(var request)
    signal linkHovered(var hoveredUrl)

    QtObject {
        id: d
    }

    Loader {
        id: webContainerLoader
        anchors.fill: parent
        sourceComponent: webEngineView
    }

    // Download + Empty Page slots for combined web views
    Loader {
        id: downloadViewLoader
        anchors.fill: parent
        active: root.isDownloadView ||
                root.isEmptyPage
        sourceComponent: root.isDownloadView ?
                             root.downloadViewComponent:
                             root.emptyPageComponent
    }

    Component {
        id: webEngineView
        BrowserWebEngineView {
            webChannel: !!root.webChannel ? root.webChannel: null
            enableJsLogs: root.isDebugEnabled
            inspectedView: !!root.inspectedView ? root.inspectedView: null

            onLinkHovered: (hoveredUrl) => root.linkHovered(hoveredUrl)
            onWindowCloseRequested: root.removeView(StackLayout.index)
            onNewWindowRequested: (request) => {
                                      if (!request.userInitiated) {
                                          console.warn("Warning: Blocked a popup window.");
                                      } else if (request.destination === WebEngineNewWindowRequest.InNewTab) {
                                          var tab = root.fnCreateEmptyTab(root.currentWebViewProfile, false, true, request.requestedUrl);
                                          tab.acceptAsNewWindow(request);
                                      } else if (request.destination === WebEngineNewWindowRequest.InNewBackgroundTab) {
                                          var backgroundTab = root.fnCreateEmptyTab(root.currentWebViewProfile, false, false, request.requestedUrl);
                                          backgroundTab.acceptAsNewWindow(request);
                                          // Disabling popups temporarily since we need to set that webengineview settings / channel and other properties
                                          /*} else if (request.destination === WebEngineNewWindowRequest.InNewDialog) {
                    var dialog = browserDialogComponent.createObject();
                    dialog.currentWebView.profile = currentWebView.profile;
                    dialog.currentWebView.webChannel = channel;
                    request.openIn(dialog.currentWebView);*/
                                      } else {
                                          // Instead of opening a new window, we open a new tab
                                          // TODO: remove "open in new window" from context menu
                                          var tab = root.fnCreateEmptyTab(root.currentWebViewProfile, false, true, request.requestedUrl);
                                          tab.acceptAsNewWindow(request);
                                      }
                                  }
            onCertificateError: (error) => root.showSslDialog(error)
            onJavaScriptDialogRequested: (request) => root.showJsDialogComponent(request)
            onShowFindBar: (numberOfMatches, activeMatch) => root.showFindBar(numberOfMatches, activeMatch)
            onResetFindBar: () => root.resetFindBar()
        }
    }
}
