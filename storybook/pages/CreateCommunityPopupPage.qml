import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ

import Storybook
import Models

import mainui

import shared.stores as SharedStores

import AppLayouts.Communities.popups
import AppLayouts.Communities.controls
import AppLayouts.Communities.stores as CommunitiesStores

import AppLayouts.stores as AppLayoutStores

SplitView {
    id: root

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

        Keychain {
            id: popupsKeychain
        }

        Popups {
            keychain: popupsKeychain
            popupParent: root
            sharedRootStore: SharedStores.RootStore {}
            rootStore: AppLayoutStores.RootStore {}
            communityTokensStore: SharedStores.CommunityTokensStore {}
            networksStore: SharedStores.NetworksStore {}
            isDevBuild: ctrlIsDevBuild.checked
        }

        Component {
            id: dlgComponent
            CreateCommunityPopup {
                id: dialog
                anchors.centerIn: parent
                destroyOnClose: true
                modal: false
                isDiscordImport: isDiscordCheckBox.checked
                isDevBuild: ctrlIsDevBuild.checked

                QtObject {
                    id: localAppSettings
                    readonly property bool testEnvironment: dialog.isDevBuild
                }

                store: CommunitiesStores.CommunitiesStore {
                    readonly property string communityTags: ModelsData.communityTags

                    function createCommunity() {
                        logs.logEvent("createCommunity")
                    }

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
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 200

        logsView.logText: logs.logText

        ColumnLayout {
            Switch {
                id: isDiscordCheckBox
                text: "Discord import"
                onToggled: {
                    if (!!dialog && dialog.opened)
                        dialog.close()
                }
            }
            Switch {
                id: ctrlIsDevBuild
                text: "Dev build"
                onToggled: {
                    if (!!dialog && dialog.opened)
                        dialog.close()
                }
            }
        }
    }
}

// category: Popups
// status: good
// https://www.figma.com/design/qHfFm7C9LwtXpfdbxssCK3/Kuba%E2%8E%9CDesktop---Communities?node-id=52741-266926&node-type=frame&t=PkDxeWSXoiZbIQXv-0
// https://www.figma.com/design/qHfFm7C9LwtXpfdbxssCK3/Kuba%E2%8E%9CDesktop---Communities?node-id=2636-359221&node-type=frame&t=PkDxeWSXoiZbIQXv-0
// https://www.figma.com/design/qHfFm7C9LwtXpfdbxssCK3/Kuba%E2%8E%9CDesktop---Communities?node-id=52741-267155&node-type=frame&t=PkDxeWSXoiZbIQXv-0
