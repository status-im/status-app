import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme

import AppLayouts.Browser.panels

import Storybook

SplitView {
    id: root

    orientation: Qt.Vertical

    Logs { id: logs }

    QtObject {
        id: mockSessionContext

        function displayTitle(webView, isStartPage) {
            return isStartPage ? "New tab" : "status.app"
        }
        function displayIcon(webView) {
            return ""
        }
    }

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Rectangle {
            anchors.fill: parent
            color: Theme.palette.baseColor4
        }

        BrowserTabView {
            id: tabView
            objectName: "browserTabView"

            anchors.top: parent.top
            anchors.left: parent.left
            width: widthSlider.value
            height: tabHeight

            currentTabIncognito: incognitoCheck.checked
            isMobile: false
            savedSessionContext: mockSessionContext
            fnGetWebView: (index) => null

            onOpenNewTabTriggered: {
                logs.logEvent("browserTabView::openNewTabTriggered")
                createEmptyTab(true)
            }
            onRemoveView: (index) => {
                              logs.logEvent("browserTabView::removeView", ["index"], arguments)
                              removeTab(index)
                          }

            Component.onCompleted: createEmptyTab(true)
        }
    }

    Pane {
        SplitView.preferredHeight: 220

        ColumnLayout {
            anchors.fill: parent

            RowLayout {
                Button {
                    text: "Add tab"
                    onClicked: tabView.createEmptyTab(true)
                }
                Button {
                    text: "Remove last tab"
                    enabled: tabView.count > 0
                    onClicked: tabView.removeTab(tabView.count - 1)
                }
                CheckBox {
                    id: incognitoCheck
                    text: "Incognito"
                }
                Label { text: "width:" }
                Slider {
                    id: widthSlider
                    from: 200
                    to: root.width
                    value: root.width
                }
            }

            // window drag is a real-input, macOS-only behaviour — the strip
            // geometry is what a headless test can check, so surface it here
            Label {
                property Item dragArea

                Component.onCompleted: {
                    for (let i = 0; i < tabView.children.length; ++i) {
                        const child = tabView.children[i]
                        if (child.objectName === "tabStripDragArea")
                            dragArea = child
                    }
                }

                text: `tabs: ${tabView.count}, strip drag area x: ${dragArea ? dragArea.x : -1}, ` +
                      `w: ${dragArea ? dragArea.width : -1}, visible: ${dragArea ? dragArea.visible : false}`
            }

            Item { Layout.fillHeight: true }
        }
    }
}

// category: Panels
// status: good
