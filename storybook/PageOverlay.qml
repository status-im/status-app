import QtCore
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core.Theme

Loader {
    id: root

    function setPage(pageName: string, pageItem: Item) {
        active = false
        d.currentPage = pageName
        d.currentPageItem = pageItem
        active = true
    }

    function clear() {
        root.active = false
    }

    QtObject {
        id: d

        property string currentPage
        property Item currentPageItem
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
                style: d.currentPageItem.Theme.style
                themePadding: d.currentPageItem.Theme.padding
                fontSizeOffset: d.currentPageItem.Theme.fontSizeOffset

                onStyleRequested: style => {
                    d.currentPageItem.Theme.style = style
                }

                onPaddingRequested: padding => {
                    d.currentPageItem.Theme.padding = padding
                }

                onPaddingFactorRequested: paddingFactor => {
                    ThemeUtils.setPaddingFactor(d.currentPageItem, paddingFactor)
                }

                onFontSizeOffsetRequested: fontSizeOffset => {
                    d.currentPageItem.Theme.fontSizeOffset = fontSizeOffset
                }

                onFontSizeRequested: fontSize => {
                    ThemeUtils.setFontSize(d.currentPageItem, fontSize)
                }

                onResetRequested: {
                    d.currentPageItem.Theme.style = undefined
                    d.currentPageItem.Theme.padding = undefined
                    d.currentPageItem.Theme.fontSizeOffset = undefined
                }
            }
        }

        Component.onCompleted: {
            if (!settings.initialized) {
                settings.initialized = true
            } else {
                d.currentPageItem.Theme.style = settings.style
                d.currentPageItem.Theme.padding = settings.padding
                d.currentPageItem.Theme.fontSizeOffset = settings.fontSizeOffset
            }

            settings.style
                    = Qt.binding(() => d.currentPageItem.Theme.style)
            settings.padding
                    = Qt.binding(() => d.currentPageItem.Theme.padding)
            settings.fontSizeOffset
                    = Qt.binding(() => d.currentPageItem.Theme.fontSizeOffset)
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
