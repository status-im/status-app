import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

import StatusQ
import StatusQ.Core.Utils as StatusQUtils

import Storybook
import Models

import AppLayouts.Communities.popups
import AppLayouts.Communities.stores as CommunitiesStores

import shared.status
import utils

SplitView {
    id: root

    Connections {
        target: Global

        function onOpenEmojiPopupRequested(params, cb) {
            const popup = emojiPopupComponent.createObject(root, params)
            popup.open()
            cb(popup)
        }
    }

    Component {
        id: emojiPopupComponent

        StatusEmojiPopup {
            height: 440
            emojiModel: StatusQUtils.Emoji.emojiModel
            onClosed: destroy()
        }
    }

    Logs { id: logs }

    orientation: Qt.Vertical

    property var dialog

    function createAndOpenDialog() {
        dialog = dlgComponent.createObject(popupBg)
        dialog.open()
    }

    Component.onCompleted: createAndOpenDialog()

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        PopupBackground {
            id: popupBg
            anchors.fill: parent

            Button {
                anchors.centerIn: parent
                text: "Reopen"

                onClicked: createAndOpenDialog()
            }
        }

        Component {
            id: dlgComponent
            CreateChannelPopup {
                id: dialog
                anchors.centerIn: parent
                destroyOnClose: true
                isEdit: ctrlIsEdit.checked
                isDeleteable: isDeleteableCheckBox.checked
                isDiscordImport: isDiscordCheckBox.checked
                chatId: isEdit ? "_general" : ""
                channelName: isEdit ? "general" : ""
                channelDescription: isEdit ? "general discussion" : ""
                activeCommunity: QtObject {
                    readonly property string id: "0x039c47e9837a1a7dcd00a6516399d0eb521ab0a92d512ca20a44ac6278bfdbb5c5"
                    readonly property string name: "test-1"
                    readonly property string image: ModelsData.icons.superRare
                    readonly property string color: dialog.isEdit ? "#4360DF" : "green"
                    readonly property int memberRole: 0
                }
                assetsModel: AssetsModel {}
                channelsModel: ChannelsModel {}
                collectiblesModel: CollectiblesModel {}
                
                permissionsModel: ListModel {
                    function belongsToChat(permissionId, chatId) {
                        return chatId === dialog.chatId
                    }

                    Component.onCompleted: {
                        if (dialog.isEdit)
                            append(PermissionsModel.channelsOnlyPermissionsModelData)
                    }
                }

                communitiesStore: CommunitiesStores.CommunitiesStore {
                    property string discordImportChannelName
                    readonly property bool discordImportInProgress: false
                    readonly property bool discordDataExtractionInProgress: false
                    readonly property int discordImportErrorsCount: 0
                    readonly property int discordImportWarningsCount: 0
                    readonly property int discordOldestMessageTimestamp: 0

                    property var discordFileList: ListModel {
                        readonly property int selectedCount: count
                        property bool selectedFilesValid
                    }

                    property var discordCategoriesModel: ListModel {}

                    property var discordChannelsModel: ListModel {
                        property bool hasSelectedItems
                        readonly property int count: 32 // hide the parsing/loading spinner
                    }

                    function setFileListItems(filePaths) {
                        for (const filePath of filePaths) {
                            discordFileList.append({"filePath": filePath, errorMessage: ""})
                        }
                    }

                    function removeFileListItem(path) {
                        for (let i = 0; i < discordFileList.count; i++) {
                            const item = discordFileList.get(i)
                            if (item.filePath === path)
                                discordFileList.remove(i)
                        }
                    }

                    function clearFileList() {
                        discordFileList.clear()
                        discordFileList.selectedFilesValid = false
                    }

                    function clearDiscordCategoriesAndChannels() {
                        discordCategoriesModel.clear()
                        discordChannelsModel.clear()
                        discordChannelsModel.hasSelectedItems = false
                    }

                    function requestExtractChannelsAndCategories() {
                        discordFileList.selectedFilesValid = true
                    }

                    function toggleOneDiscordChannel(id) {
                        logs.logEvent("toggleOneDiscordChannel", ["id"], arguments)
                    }

                    function resetDiscordImport() {
                        logs.logEvent("resetDiscordImport")
                    }

                    function requestCancelDiscordChannelImport(id) {
                        logs.logEvent("requestCancelDiscordChannelImport", ["id"], arguments)
                    }

                    function requestImportDiscordChannel(args, timestamp) {
                        logs.logEvent("requestImportDiscordChannel", ["args", "timestamp"], arguments)
                    }
                }

                onCreateCommunityChannel: function(chName, chDescription, chEmoji, chColor, chCategoryId, viewOnlyCanAddReaction, hideIfPermissionsNotMet) {
                    logs.logEvent("onCreateCommunityChannel",
                                  ["chName", "chDescription", "chEmoji", "chColor", "chCategoryId",
                                   "viewOnlyCanAddReaction", "hideIfPermissionsNotMet"], arguments)
                }

                onEditCommunityChannel: function(chName, chDescription, chEmoji, chColor, chCategoryId, viewOnlyCanAddReaction, hideIfPermissionsNotMet) {
                    logs.logEvent("onEditCommunityChannel",
                                  ["chName", "chDescription", "chEmoji", "chColor", "chCategoryId",
                                   "viewOnlyCanAddReaction", "hideIfPermissionsNotMet"], arguments)
                }

                onDeleteCommunityChannel: logs.logEvent("onDeleteCommunityChannel")
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 200

        logsView.logText: logs.logText

        ColumnLayout {
            RowLayout {
                RadioButton {
                    text: "Create mode"
                    checked: true
                }
                RadioButton {
                    id: ctrlIsEdit
                    text: "Edit mode"
                }
                RadioButton {
                    id: isDiscordCheckBox
                    text: "isDiscordImport"
                    onToggled: {
                        if (!!dialog && dialog.opened)
                            dialog.close()
                    }
                }
            }
            Switch {
                id: isDeleteableCheckBox
                text: "isDeleteable"
                enabled: ctrlIsEdit.checked
            }
        }
    }
}

// category: Popups

// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=2975%3A488608
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=2975%3A488256
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=2903%3A348301
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=2975%3A488848
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=2975%3A489237
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=2975%3A489607
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=2975%3A492910
