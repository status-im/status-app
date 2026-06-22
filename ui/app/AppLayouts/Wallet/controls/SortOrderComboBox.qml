import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Components.private as SQP
import StatusQ.Core.Theme
import StatusQ.Popups

import utils

ComboBox {
    id: root

    // expected model role names: text, value (enum TokenOrder), sortRoleName, icon (optional), isDisabled (optional) default is false
    // text === "---" denotes a separator

    property bool hasCustomOrderDefined

    property int currentSortOrder: Qt.DescendingOrder
    readonly property string currentSortRoleName: root.currentIndex !== -1 ? root.model[root.currentIndex].sortRoleName : ""

    signal createOrEditRequested()

    textRole: "text"
    valueRole: "value"

    displayText: root.currentValue === SortOrderComboBox.TokenOrderCustom ? currentText
                                                                          : "%1 %2".arg(currentText).arg(currentSortOrder === Qt.DescendingOrder ? "↓" : "↑")

    onActivated: function(index) {
        if (index === indexOfValue(SortOrderComboBox.TokenOrderCreateCustom)) { // restore the previous sort role and signal we want create/edit
            currentIndex = d.currentIndex
            root.createOrEditRequested()
        } else {
            if (index === indexOfValue(SortOrderComboBox.TokenOrderCustom))
                currentSortOrder = Qt.AscendingOrder
            else if (d.currentIndex === index)  // just keep the same sort role and flip the up/down
                currentSortOrder = currentSortOrder === Qt.AscendingOrder ? Qt.DescendingOrder : Qt.AscendingOrder

            // update internal index
            d.currentIndex = index
        }
    }

    Component.onCompleted: {
        d.currentIndex = root.currentIndex // sync with settings which might arrive from the outside
    }

    enum TokenOrder {
        TokenOrderNone = 0,
        TokenOrderCurrencyBalance, // FIAT value of asset balance (enabledNetworkCurrencyBalance)
        TokenOrderBalance, // Number of tokens (enabledNetworkBalance)
        TokenOrderCurrencyPrice, // Value per token in FIAT (currencyPrice)
        TokenOrder1DChange, // Level of change in asset balance value (in FIAT) comp. to 1 day earlier
        TokenOrderAlpha, // Alphabetic by asset name (name)
        TokenOrderDateAdded, // Date added descending (newest first)
        TokenOrderGroupName, // Collection or Community name
        TokenOrderCustom, // Custom (user created) order
        TokenOrderCreateCustom // special menu entry to create/edit the custom sort order
    }

    horizontalPadding: 12
    verticalPadding: Theme.halfPadding
    spacing: Theme.halfPadding

    font.family: Fonts.baseFont.family
    font.pixelSize: Theme.additionalTextSize

    QtObject {
        id: d

        readonly property int defaultDelegateHeight: 34

        property int currentIndex: 0
    }

    background: SQP.StatusComboboxBackground {
        active: root.down || root.hovered
    }

    contentItem: StatusBaseText {
        leftPadding: root.horizontalPadding
        rightPadding: root.horizontalPadding
        font.pixelSize: root.font.pixelSize
        font.weight: Font.Medium
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: root.displayText
        color: Theme.palette.baseColor1
    }

    indicator: SQP.StatusComboboxIndicator {
        x: root.mirrored ? root.horizontalPadding : root.width - width - root.horizontalPadding
        y: root.topPadding + (root.availableHeight - height) / 2
    }

    popup: StatusDropdown {
        id: dropdown

        directParent: root
        relativeY: root.height + 4

        implicitWidth: 290

        padding: 1
        verticalPadding: Theme.halfPadding

        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            StatusMenuHeadline {
                Layout.fillWidth: true
                Layout.preferredHeight: d.defaultDelegateHeight
                text: qsTr("Sort by")
            }
            StatusListView {
                objectName: "sortOrderListView"

                Layout.fillWidth: true
                implicitWidth: contentWidth
                implicitHeight: contentHeight

                model: root.popup.visible ? root.delegateModel : null
                currentIndex: root.highlightedIndex
            }
        }
    }

    Component {
        id: regularMenuComponent
        RowLayout {
            spacing: root.spacing

            StatusIcon {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                visible: !!icon
                icon: iconName
                color: root.enabled ? Theme.palette.primaryColor1 : Theme.palette.baseColor1
            }

            StatusBaseText {
                Layout.fillWidth: true
                text: menuText
                elide: Text.ElideRight
                color: isEditAction ? Theme.palette.primaryColor1 : root.enabled ? Theme.palette.directColor1 : Theme.palette.baseColor1
                font.pixelSize: root.font.pixelSize
            }

            Item { Layout.fillWidth: true }

            Row {
                visible: showUpDownArrows
                spacing: 4
                StatusFlatRoundButton {
                    objectName: "sortArrowUp"
                    radius: 6
                    width: 24
                    height: 24
                    icon.name: "arrow-up"
                    icon.width: 18
                    icon.height: 18
                    opacity: root.highlightedIndex === menuIndex || highlighted // not "visible, we want the item to stay put
                    highlighted: root.currentIndex === menuIndex && root.currentSortOrder === Qt.AscendingOrder
                    onClicked: {
                        if (root.currentIndex !== menuIndex)
                            root.currentIndex = menuIndex
                        d.currentIndex = menuIndex
                        root.currentSortOrder = Qt.AscendingOrder
                        root.popup.close()
                    }
                }
                StatusFlatRoundButton {
                    objectName: "sortArrowDown"
                    radius: 6
                    width: 24
                    height: 24
                    icon.name: "arrow-down"
                    icon.width: 18
                    icon.height: 18
                    opacity: root.highlightedIndex === menuIndex || highlighted // not "visible, we want the item to stay put
                    highlighted: root.currentIndex === menuIndex && root.currentSortOrder === Qt.DescendingOrder
                    onClicked: {
                        if (root.currentIndex !== menuIndex)
                            root.currentIndex = menuIndex
                        d.currentIndex = menuIndex
                        root.currentSortOrder = Qt.DescendingOrder
                        root.popup.close()
                    }
                }
            }
        }
    }

    Component {
        id: separatorMenuComponent
        StatusMenuSeparator {
            topPadding: 0
            bottomPadding: 0
        }
    }

    delegate: ItemDelegate {
        id: menuDelegate

        required property int index
        required property var modelData

        readonly property bool isSeparator: text === "---"

        width: ListView.view.width
        highlighted: root.highlightedIndex === index
        enabled: !isSeparator

        readonly property bool custom:
            modelData["value"] === SortOrderComboBox.TokenOrderCustom

        visible: {
            if (modelData["isDisabled"]) {
                return false;
            }
            if (custom) // hide "Custom order" menu entry if none defined
                return root.hasCustomOrderDefined
            return true
        }
        height: visible ? implicitHeight : 0
        leftPadding: isSeparator ? 0 : 14
        rightPadding: isSeparator ? 0 : 8
        verticalPadding: isSeparator ? 2 : 5
        spacing: root.spacing
        font: root.font
        text: root.textRole ? modelData[root.textRole] : modelData
        icon.name: !!modelData["icon"] ? modelData["icon"] : ""
        icon.color: Theme.palette.primaryColor1
        background: Rectangle {
            implicitHeight: parent.isSeparator ? 3 : d.defaultDelegateHeight
            color: {
                if (menuDelegate.index === root.currentIndex)
                    return Theme.palette.primaryColor3
                if (menuDelegate.highlighted)
                    return Theme.palette.statusMenu.hoverBackgroundColor

                return "transparent"
            }
            HoverHandler {
                cursorShape: root.enabled ? Qt.PointingHandCursor : undefined
            }
        }
        contentItem: Loader {
            readonly property int menuIndex: menuDelegate.index
            readonly property string menuText: menuDelegate.text
            readonly property string iconName: menuDelegate.icon.name
            readonly property bool showUpDownArrows: !menuDelegate.custom && menuDelegate.modelData["sortRoleName"] !== ""
            readonly property bool isEditAction: modelData["value"] === SortOrderComboBox.TokenOrderCreateCustom
            sourceComponent: menuDelegate.isSeparator ? separatorMenuComponent : regularMenuComponent
        }
    }
}
