import QtCore
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core.Theme

Loader {
    id: root

    function setPage(pageName: string) {
        active = false
        d.currentPage = pageName
        active = true
    }

    function clear() {
        root.active = false
    }

    QtObject {
        id: d

        property string currentPage
        readonly property Window currentWindow: root.Window.window
    }

    active: false

    sourceComponent: Item {
        RoundButton {
            id: openPopupButton

            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 5

            text: "🎨📏"
            font.pixelSize: 20

            checkable: true
            checked: popup.visible

            onClicked: {
                if (!popup.visible)
                    popup.open()
                else
                    popup.close()
            }
        }

        Popup {
            id: popup

            parent: openPopupButton

            x: -width + parent.width
            y: parent.height + 5

            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

            PageOverlayPanel {
                style: d.currentWindow.Theme.style
                themePadding: d.currentWindow.Theme.padding
                fontSizeOffset: d.currentWindow.Theme.fontSizeOffset

                onStyleRequested: style => {
                    d.currentWindow.Theme.style = style
                }

                onPaddingRequested: padding => {
                    d.currentWindow.Theme.padding = padding
                }

                onPaddingFactorRequested: paddingFactor => {
                    ThemeUtils.setPaddingFactor(d.currentWindow, paddingFactor)
                }

                onFontSizeOffsetRequested: fontSizeOffset => {
                    d.currentWindow.Theme.fontSizeOffset = fontSizeOffset
                }

                onFontSizeRequested: fontSize => {
                    ThemeUtils.setFontSize(d.currentWindow, fontSize)
                }

                onResetRequested: {
                    d.currentWindow.Theme.style = undefined
                    d.currentWindow.Theme.padding = undefined
                    d.currentWindow.Theme.fontSizeOffset = undefined
                }
            }
        }

        Component.onCompleted: {
            if (!settings.initialized) {
                settings.initialized = true
            } else {
                d.currentWindow.Theme.style = settings.style
                d.currentWindow.Theme.padding = settings.padding
                d.currentWindow.Theme.fontSizeOffset = settings.fontSizeOffset
            }

            settings.style
                    = Qt.binding(() => d.currentWindow.Theme.style)
            settings.padding
                    = Qt.binding(() => d.currentWindow.Theme.padding)
            settings.fontSizeOffset
                    = Qt.binding(() => d.currentWindow.Theme.fontSizeOffset)
        }

        Settings {
            id: settings

            category: "page_" + d.currentPage

            property bool initialized
            property int style
            property real padding
            property int fontSizeOffset
        }
    }
}
