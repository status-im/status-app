import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components

import utils

import SortFilterProxyModel

StatusTextField {
    id: root

    required property url url
    required property bool incognitoMode
    required property color bgColor

    property url faviconUrl
    property bool showFavicon
    property bool loading

    property var autocompleteHistory

    readonly property url searchEngineIcon: Assets.svg(SearchEnginesConfig.getEngineIcon(localAccountSensitiveSettings.selectedBrowserSearchEngineId))

    signal navigationRequested(string url)

    implicitHeight: 40

    background: Rectangle {
        color: root.bgColor
        radius: Theme.radius
    }
    verticalAlignment: TextInput.AlignVCenter
    leftPadding: showFavicon ? Theme.halfPadding + favicon.width + favicon.anchors.leftMargin
                             : Theme.padding
    rightPadding: clearButton.width
    placeholderText: qsTr("Search or enter address")
    color: root.incognitoMode ? Theme.palette.privacyColors.tertiary : Theme.palette.textColor

    inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | Qt.ImhSensitiveData
    EnterKey.type: Qt.EnterKeyGo

    text: root.url

    onActiveFocusChanged: {
        if (activeFocus) {
            selectAll()
        } else if (!dropdown.visible) {
            if (text !== root.url.toString() && root.url.toString() !== "") // restore the old (non empty) URL
                text = Qt.binding(() => root.url)
        }
    }

    onAccepted: {
        dropdown.close()
        navigationRequested(text)
    }

    StatusRoundedImage {
        id: favicon
        visible: root.showFavicon
        height: parent.height*.6
        width: height
        anchors.left: parent.left
        anchors.leftMargin: height/2
        anchors.verticalCenter: parent.verticalCenter
        image.sourceSize: Qt.size(width, height)
        image.source: {
            if (root.url.toString() !== root.text || root.text === "") {
                return root.searchEngineIcon
            }

            if (root.showFavicon) {
                if (root.faviconUrl.toString() !== "" )
                    return root.faviconUrl
                return Assets.svg("globe")
            }

            return root.searchEngineIcon
        }
    }

    StatusClearButton {
        id: clearButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: parent.cursorVisible && !!parent.text
        tooltip.orientation: StatusToolTip.Orientation.Bottom
        onClicked: parent.clear()
    }

    SortFilterProxyModel {
        id: sfpm
        sourceModel: root.autocompleteHistory
        filters: [
            SQUtils.SearchFilter {
                roleName: "escapedUrl"
                searchPhrase: root.text
            }
        ]
        sorters: [
            RoleSorter {
                roleName: "timestamp"
                sortOrder: Qt.DescendingOrder
            },
            StringSorter {
                roleName: "url"
                caseSensitivity: Qt.CaseInsensitive
            }
        ]
    }

    Keys.forwardTo: dropdown
    Keys.onEscapePressed: {
        dropdown.close()
        root.focus = sfpm.count > 0
    }
    Keys.onDownPressed: {
        if (dropdown.visible) {
            selectorPanel.forceActiveFocus()
            selectorPanel.currentIndex = 0
        }
    }

    StatusDropdown {
        id: dropdown

        directParent: root
        relativeX: root.width - width
        relativeY: root.height + 2
        width: root.width
        bottomSheetAllowed: false
        padding: 0
        focus: false
        dim: false

        visible: sfpm.count > 0 && root.text !== ""

        contentItem: StatusListView {
            id: selectorPanel
            width: root.width
            implicitHeight: contentHeight
            model: sfpm
            currentIndex: -1
            highlightFollowsCurrentItem: true
            highlight: Rectangle {
                radius: Theme.radius
                color: selectorPanel.activeFocus ? Theme.palette.primaryColor2 : StatusColors.transparent
            }
            Keys.onUpPressed: {
                if (currentIndex === 0)
                    root.forceActiveFocus()
                else
                    currentIndex--
            }

            delegate: ItemDelegate {
                width: ListView.view.width - Theme.padding
                background: Rectangle {
                    radius: Theme.radius
                    color: selectorPanel.activeFocus ? StatusColors.transparent
                                                     : hovered ? Theme.palette.primaryColor2
                                                               : StatusColors.transparent
                }
                contentItem: RowLayout {
                    StatusIcon {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        icon: model.isSearch ? "search" : "globe"
                        color: Theme.palette.primaryColor1
                    }
                    StatusBaseText {
                        Layout.fillWidth: true
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
                        text: model.url
                        font.pixelSize: Theme.fontSize(14)
                    }
                }
                onClicked: {
                    dropdown.close()
                    root.navigationRequested(model.url)
                }
                HoverHandler {
                    cursorShape: hovered ? Qt.PointingHandCursor : undefined
                }
            }
        }

        onClosed: selectorPanel.currentIndex = -1
    }
}
