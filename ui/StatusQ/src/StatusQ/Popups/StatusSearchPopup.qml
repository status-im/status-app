import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups
import StatusQ.Core.Utils


StatusModal {
    id: root
    width: 700
    height: !!searchResults && searchResults.count >= 0 && searchText !== "" ? 560 : 200
    showHeader: false
    showFooter: false

    property string searchText: contentItem.searchText
    property string noResultsLabel: qsTr("No results")
    property string defaultSearchLocationText: qsTr("Anywhere")
    property bool loading: false
    property var searchOptionsPopupMenu: Menu { }
    property var searchResults: [ ]
    property var searchSelectionButton
    // This function is called to know if the popup accepts clicks in the title
    // If it does not, the clicks on the titles mousearea will be propagated to the main body instead
    property var acceptsTitleClick: function(titleId) {return true}

    signal resultItemClicked(string itemId)
    signal resultItemTitleClicked(string titleId)
    signal resetSearchLocationClicked()

    property var formatTimestampFn: function (ts) {
        return ts
    }

    function setSearchSelection(text = "",
                                secondaryText = "",
                                imageSource = "",
                                isIdenticon = "",
                                iconName = "",
                                iconColor = "",
                                isUserIcon = false,
                                colorId = 0) {
        searchSelectionButton.primaryText = text
        searchSelectionButton.secondaryText = secondaryText
        searchSelectionButton.asset.imgIsIdenticon = isIdenticon
        searchSelectionButton.asset.isImage = !!imageSource
        searchSelectionButton.asset.name = !!imageSource ? imageSource : iconName
        searchSelectionButton.asset.color = isUserIcon ? Theme.palette.userCustomizationColors[colorId] : iconColor
        searchSelectionButton.asset.isLetterIdenticon = !iconName && !imageSource
        searchSelectionButton.asset.charactersLen = isUserIcon ? 2 : 1
    }

    function resetSearchSelection() {
        setSearchSelection(defaultSearchLocationText, "", "", false, "", "transparent")
    }

    function forceActiveFocus() {
        if (Utils.isMobile)
            return
        contentItem.searchInput.input.edit.forceActiveFocus()
    }

    onOpened: {
        if (Utils.isMobile)
            return
        forceActiveFocus();
    }

    contentItem: Item {
        property alias searchText: inputText.text
        property alias searchInput: inputText

        ColumnLayout {
            id: contentItemColumn
            anchors.fill: parent
            spacing: 0
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 63
                StatusIcon {
                    id: statusIcon
                    width: 40
                    height: 40
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "search"
                    color: Theme.palette.baseColor1
                }

                StatusInput {
                    id: inputText
                    input.edit.objectName: "searchPopupSearchInput"
                    anchors.left: statusIcon.right
                    anchors.right: closePopupButton.left
                    anchors.verticalCenter: parent.verticalCenter
                    focus: !Utils.isMobile
                    font.pixelSize: Theme.fontSize(28)
                    leftPadding: 5
                    topPadding: 5 //smaller padding to handle bigger font
                    bottomPadding: 5
                    input.clearable: true
                    input.showBackground: false
                    input.placeholder {
                        text: qsTr("Search")
                        font.pixelSize: Theme.fontSize(28)
                        color: Theme.palette.directColor9
                    }

                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return)
                            event.accepted = true
                    }
                }

                StatusFlatRoundButton {
                    id: closePopupButton
                    objectName: "headerCloseButton"
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    type: StatusFlatRoundButton.Type.Secondary
                    icon.name: "close"
                    icon.color: Theme.palette.directColor1
                    icon.width: 24
                    icon.height: 24
                    onClicked: root.close()
                }
            }
            StatusMenuSeparator {
                verticalPadding: 0
                Layout.fillWidth: true
            }
            Item {
                Layout.preferredWidth: parent.width
                Layout.preferredHeight: 58
                Button {
                    id: searchOptionsMenuButton

                    Component.onCompleted: {
                        root.searchSelectionButton = searchOptionsMenuButton
                    }

                    property string primaryText: ""
                    property string secondaryText: ""
                    property StatusAssetSettings asset: StatusAssetSettings {
                        width: 16
                        height: 16
                        name: ""
                        isLetterIdenticon: false
                        letterSize: charactersLen > 1 ? 8 : 11
                        imgIsIdenticon: false
                    }

                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter

                    implicitWidth: (contentItemRowLayout.width + 24)
                    implicitHeight: 32

                    background: Rectangle {
                        anchors.fill: parent
                        color: Theme.palette.baseColor2
                        radius: 8
                    }

                    contentItem: Item {
                        anchors.fill: parent

                        StatusMouseArea {
                            id: sensor
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.searchOptionsPopupMenu.popup();

                            RowLayout {
                                id: contentItemRowLayout
                                anchors.centerIn: parent
                                spacing: 2
                                StatusBaseText {
                                    color: Theme.palette.directColor1
                                    text: qsTr("In: ")
                                    font.weight: Font.Medium
                                    font.pixelSize: Theme.primaryTextFontSize
                                }

                                StatusSmartIdenticon {
                                    id: identicon
                                    Layout.preferredWidth: active ? 16 : 0
                                    Layout.preferredHeight: 16
                                    asset: searchOptionsMenuButton.asset
                                    name: searchOptionsMenuButton.primaryText
                                    active: searchOptionsMenuButton.primaryText !== defaultSearchLocationText &&
                                            (searchOptionsMenuButton.asset.name ||
                                             searchOptionsMenuButton.asset.isLetterIdenticon)
                                }

                                StatusBaseText {
                                    Layout.alignment: Qt.AlignVCenter
                                    color: Theme.palette.directColor1
                                    text: searchOptionsMenuButton.primaryText
                                    font.weight: Font.Medium
                                    font.pixelSize: Theme.additionalTextSize
                                }
                                StatusIcon {
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    Layout.alignment: Qt.AlignVCenter
                                    visible: !!searchOptionsMenuButton.secondaryText
                                    color: Theme.palette.baseColor1
                                    icon: "next"
                                }
                                StatusIcon {
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    Layout.alignment: Qt.AlignVCenter
                                    visible: !!searchOptionsMenuButton.secondaryText
                                    color: Theme.palette.directColor1
                                    icon: "channel"
                                }
                                StatusBaseText {
                                    Layout.alignment: Qt.AlignVCenter
                                    color: Theme.palette.directColor1
                                    visible: !!searchOptionsMenuButton.secondaryText
                                    text: searchOptionsMenuButton.secondaryText
                                    font.weight: Font.Medium
                                    font.pixelSize: Theme.additionalTextSize
                                }
                                StatusIcon {
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    Layout.alignment: Qt.AlignVCenter
                                    icon: "chevron-down"
                                    color: Theme.palette.directColor1
                                }
                            }
                        }
                    }
                }

                StatusFlatRoundButton {
                    id: closeButton
                    objectName: "searchModalResetSearchButton"
                    width: 32
                    height: 32
                    anchors.left: searchOptionsMenuButton.right
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: (searchOptionsMenuButton.primaryText === defaultSearchLocationText) ? 0.0 : 1.0
                    visible: (opacity > 0.1)
                    type: StatusFlatRoundButton.Type.Secondary
                    icon.name: "close"
                    icon.color: Theme.palette.directColor1
                    onClicked: { root.resetSearchLocationClicked(); }
                }
            }
            StatusMenuSeparator {
                verticalPadding: 0
                Layout.fillWidth: true;
                visible: root.height > 142
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ListView {
                    id: view
                    objectName: "searchResultListView"
                    anchors.fill: parent
                    anchors {
                        leftMargin: 0
                        rightMargin: 0
                        bottomMargin: 67
                    }
                    visible: (!root.loading && (count > 0))
                    model: root.searchResults
                    ScrollBar.vertical: ScrollBar { }
                    delegate: StatusListItem {
                        width: view.width
                        itemId: model.itemId
                        titleId: model.titleId
                        title: model.title
                        statusListItemTitle.color: model.title.startsWith("@") ? Theme.palette.primaryColor1 : Theme.palette.directColor1
                        subTitle: model.content
                        radius: 0
                        statusListItemSubTitle.height: model.content !== "" ? 20 : 0
                        statusListItemSubTitle.elide: Text.ElideRight
                        statusListItemSubTitle.color: Theme.palette.directColor1
                        asset.isLetterIdenticon: (model.image === "")
                        asset.color: model.isUserIcon ? Theme.palette.userCustomizationColors[model.colorId] : model.color
                        asset.charactersLen: model.isUserIcon ? 2 : 1
                        titleAsideText: root.formatTimestampFn(model.time)
                        asset.name: model.image
                        asset.width: 40
                        asset.height: 40
                        asset.isImage: !!model.image
                        badge.primaryText: model.badgePrimaryText
                        badge.secondaryText: model.badgeSecondaryText
                        badge.asset.name: model.badgeImage
                        badge.asset.isLetterIdenticon: model.badgeIsLetterIdenticon
                        badge.asset.color: model.badgeIconColor

                        onClicked: {
                            root.resultItemClicked(itemId)
                        }

                        propagateTitleClicks: !root.acceptsTitleClick(titleId)
                        onTitleClicked: (titleId, mouse) => {
                            if (root.acceptsTitleClick(titleId)) {
                                root.resultItemTitleClicked(titleId)
                            }
                        }
                    }
                    section.property: "sectionName"
                    section.criteria: ViewSection.FullString
                    section.delegate: Item {
                        height: 34
                        width: view.width
                        StatusBaseText {
                            font.pixelSize: Theme.primaryTextFontSize
                            color: Theme.palette.baseColor1
                            text: section
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                        }
                    }
                }
                StatusLoadingIndicator {
                    objectName: "searchPopupLoadingIndicator"
                    anchors.centerIn: parent
                    visible: root.loading
                    color: Theme.palette.primaryColor1
                    width: 24
                    height: 24
                }

                StatusBaseText {
                    anchors.centerIn: parent
                    text: root.noResultsLabel
                    color: Theme.palette.baseColor1
                    font.pixelSize: Theme.additionalTextSize
                    visible: ((inputText.text !== "") && (view.count === 0) && !root.loading)
                }
            }
        }
    }
    onClosed: {
        root.resetSearchSelection();
        root.loading = false;
        contentItem.searchText = "";
    }
}
