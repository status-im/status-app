import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils
import shared.panels
import shared.popups

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Controls.Validators
import StatusQ.Popups
import StatusQ.Popups.Dialog

import AppLayouts.Communities.controls
import AppLayouts.Communities.panels
import AppLayouts.Communities.stores
import AppLayouts.Profile.stores

StatusStackModal {
    id: root

    property CommunitiesStore store
    property AdvancedStore advancedStore
    property bool isDiscordImport // creating new or importing from discord?
    property bool isDevBuild

    stackTitle: isDiscordImport ? qsTr("Import a community from Discord into Status") :
                                  qsTr("Create New Community")
    width: 640

    closePolicy: Popup.NoAutoClose // explicit [x] click needed, or via the `close()` method

    nextButton: StatusButton {
        objectName: "createCommunityNextBtn"
        text: typeof currentItem.nextButtonText !== "undefined" ? currentItem.nextButtonText : qsTr("Next")
        enabled: typeof(currentItem.canGoNext) == "undefined" || currentItem.canGoNext
        loading: root.store.discordDataExtractionInProgress
        onClicked: {
            let nextAction = currentItem.nextAction
            if (typeof(nextAction) == "function") {
                return nextAction()
            }
            root.currentIndex++
        }
    }

    finishButton: StatusButton {
        objectName: "createCommunityFinalBtn"
        text: root.isDiscordImport ? qsTr("Start Discord import") : qsTr("Create Community")
        enabled: typeof(currentItem.canGoNext) == "undefined" || currentItem.canGoNext
        onClicked: {
            let nextAction = currentItem.nextAction
            if (typeof (nextAction) == "function") {
                return nextAction()
            }
        }
    }

    readonly property var clearFilesButton: StatusButton {
        text: qsTr("Clear all")
        type: StatusBaseButton.Type.Danger
        visible: root.currentItem.objectName === "discordFileListView" // no better way to address the current item in the stack :/
        enabled: !fileListView.fileListModelEmpty && !root.store.discordDataExtractionInProgress
        onClicked: root.store.clearFileList()
    }

    rightButtons: [clearFilesButton, nextButton, finishButton]

    onAboutToShow: {
        if (root.isDiscordImport) {
            if (!root.store.discordImportInProgress) {
                root.store.clearFileList()
                root.store.clearDiscordCategoriesAndChannels()
            }
            for (let i = 0; i < discordPages.length; i++) {
                stackItems.push(discordPages[i])
            }
        }
    }

    readonly property list<Item> discordPages: [
        ColumnLayout {
            id: fileListView
            objectName: "discordFileListView" // !!! DON'T CHANGE, clearFilesButton depends on this
            spacing: 24
            readonly property var fileListModel: root.store.discordFileList
            readonly property bool fileListModelEmpty: !fileListModel.count

            readonly property bool canGoNext: fileListModel.selectedCount
                                              || (fileListModel.selectedCount && fileListModel.selectedFilesValid)
            readonly property string nextButtonText:
                fileListModel.selectedCount && fileListModel.selectedFilesValid ? qsTr("Proceed with (%1/%2) files").arg(fileListModel.selectedCount).arg(fileListModel.count) :
                fileListModel.selectedCount ? qsTr("Validate (%1/%2) files").arg(fileListModel.selectedCount).arg(fileListModel.count)
                : qsTr("Import files")
            readonly property var nextAction: function () {
                if (!fileListView.fileListModel.selectedFilesValid) {
                    return root.store.requestExtractChannelsAndCategories()
                }
                root.currentIndex++
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                StatusBaseText {
                    Layout.fillWidth: true
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    text: fileListView.fileListModelEmpty ? qsTr("Select Discord JSON files to import") :
                                                            root.store.discordImportErrorsCount ? qsTr("Some of your community files cannot be used") :
                                                                                                  qsTr("Uncheck any files you would like to exclude from the import")
                }
                StatusBaseText {
                    visible: fileListView.fileListModelEmpty && !issuePill.visible
                    font.pixelSize: Theme.tertiaryTextFontSize
                    color: Theme.palette.baseColor1
                    text: qsTr("(JSON file format only)")
                }
                IssuePill {
                    id: issuePill
                    type: root.store.discordImportErrorsCount ? IssuePill.Type.Error : IssuePill.Type.Warning
                    count: root.store.discordImportErrorsCount || root.store.discordImportWarningsCount || 0
                    visible: !!count && !fileListView.fileListModelEmpty
                }
                StatusButton {
                    Layout.alignment: Qt.AlignRight
                    text: qsTr("Browse files")
                    type: StatusBaseButton.Type.Primary
                    onClicked: fileDialog.open()
                    enabled: !root.store.discordDataExtractionInProgress
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.palette.baseColor4

                ColumnLayout {
                    visible: fileListView.fileListModelEmpty
                    anchors.top: parent.top
                    anchors.topMargin: 60
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    StatusRoundIcon {
                        Layout.alignment: Qt.AlignHCenter
                        asset.name: "info"
                    }
                    StatusBaseText {
                        Layout.topMargin: 8
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Qt.AlignHCenter
                        text: qsTr("Export your Discord JSON data using %1").arg("<a href='https://github.com/Tyrrrz/DiscordChatExporter/releases/tag/2.40.4'>DiscordChatExporter</a>")
                        onLinkActivated: link => Global.requestOpenLink(link)
                        HoverHandler {
                            id: handler1
                        }
                        StatusMouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            cursorShape: handler1.hovered && parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                        }
                    }
                    StatusBaseText {
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Qt.AlignHCenter
                        text: qsTr("Refer to this <a href='https://github.com/Tyrrrz/DiscordChatExporter/blob/master/.docs/Readme.md'>documentation</a> if you have any queries")
                        onLinkActivated: link => Global.requestOpenLink(link)
                        HoverHandler {
                            id: handler2
                        }
                        StatusMouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            cursorShape: handler2.hovered && parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                        }
                    }
                }

                StatusListView {
                    visible: !fileListView.fileListModelEmpty
                    enabled: !root.store.discordDataExtractionInProgress
                    anchors.fill: parent
                    anchors.margins: 16
                    model: fileListView.fileListModel
                    delegate: ColumnLayout {
                        width: ListView.view.width
                        RowLayout {
                            spacing: 20
                            Layout.fillWidth: true
                            Layout.topMargin: 8
                            StatusBaseText {
                                Layout.fillWidth: true
                                text: model.filePath
                                font.pixelSize: Theme.additionalTextSize
                                elide: Text.ElideRight
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                            }

                            StatusFlatRoundButton {
                                id: removeButton
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                type: StatusFlatRoundButton.Type.Secondary
                                icon.name: "close"
                                icon.color: Theme.palette.directColor1
                                icon.width: 24
                                icon.height: 24
                                onClicked: root.store.removeFileListItem(model.filePath)
                            }
                        }


                        StatusBaseText {
                            Layout.fillWidth: true
                            text: "%1 %2".arg("⚠").arg(model.errorMessage)
                            visible: model.errorMessage
                            font.pixelSize: Theme.additionalTextSize
                            font.weight: Font.Medium
                            elide: Text.ElideMiddle
                            color: Theme.palette.dangerColor1
                            verticalAlignment: Qt.AlignTop
                        }
                    }
                }
            }

            StatusFileDialog {
                id: fileDialog

                title: qsTr("Choose files to import")
                selectMultiple: true
                nameFilters: [qsTr("JSON files (%1)").arg("*.json")]
                onAccepted: {
                    if (fileDialog.selectedFiles.length > 0) {
                        root.store.setFileListItems(UrlUtils.convertUrlsToLocalPaths(fileDialog.selectedFiles))
                    }
                }
            }
        },

        ColumnLayout {
            id: categoriesAndChannelsView
            spacing: 24

            readonly property bool canGoNext: root.store.discordChannelsModel.hasSelectedItems
            readonly property var nextAction: function () {
                d.requestImportDiscordCommunity()
                // replace ourselves with the progress dialog, no way back
                root.leftButtons[0].visible = false
                root.backgroundColor = Theme.palette.baseColor4
                root.replace(progressComponent)
            }

            Component {
                id: progressComponent
                DiscordImportProgressContents {
                    width: root.availableWidth
                    store: root.store
                    onClose: root.close()
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !root.store.discordChannelsModel.count
                Loader {
                    anchors.centerIn: parent
                    active: parent.visible
                    sourceComponent: StatusLoadingIndicator {
                        width: 50
                        height: 50
                    }
                }
            }

            ColumnLayout {
                spacing: 12
                visible: root.store.discordChannelsModel.count

                StatusBaseText {
                    Layout.fillWidth: true
                    text: qsTr("Please select the categories and channels you would like to import")
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    spacing: 20
                    Layout.fillWidth: true
                    StatusRadioButton {
                        text: qsTr("Import all history")
                        checked: true
                    }
                    StatusRadioButton {
                        id: startDateRadio
                        text: qsTr("Start date")
                    }
                    StatusDatePicker {
                        id: datePicker
                        Layout.fillWidth: true
                        selectedDate: new Date(root.store.discordOldestMessageTimestamp * 1000)
                        enabled: startDateRadio.checked
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.palette.baseColor4

                    StatusListView {
                        anchors.fill: parent
                        anchors.margins: 16
                        model: root.store.discordCategoriesModel
                        delegate: ColumnLayout {
                            width: ListView.view.width
                            spacing: 8

                            StatusCheckBox {
                                readonly property string categoryId: model.id
                                id: categoryCheckbox
                                checked: model.selected
                                text: model.name
                                onToggled: root.store.toggleDiscordCategory(categoryId, checked)
                            }

                            ColumnLayout {
                                spacing: 8
                                Layout.fillWidth: true
                                Layout.leftMargin: 24
                                Repeater {
                                    Layout.fillWidth: true
                                    model: root.store.discordChannelsModel
                                    delegate: StatusCheckBox {
                                        width: parent.width
                                        text: model.name
                                        checked: model.selected
                                        visible: model.categoryId === categoryCheckbox.categoryId
                                        onToggled: root.store.toggleDiscordChannel(model.id, checked)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    ]

    stackItems: [
        StatusScrollView {
            id: generalView
            contentWidth: availableWidth

            readonly property var nextAction: () => {
                if (generalViewLayout.validate(root.isDevBuild)) {
                    root.currentIndex++
                }
            }

            padding: 0
            clip: false

            ScrollBar.vertical: StatusScrollBar {
                parent: root
                anchors.top: generalView.top
                anchors.bottom: generalView.bottom
                anchors.left: generalView.right
                anchors.leftMargin: 1
            }

            EditCommunitySettingsForm {
                id: generalViewLayout
                width: generalView.availableWidth

                nameLabel: qsTr("Name your community")
                descriptionLabel: qsTr("Give it a short description")

                tags: root.store.communityTags
            }
        },

        ColumnLayout {
            id: introOutroMessageView
            spacing: Theme.padding

            readonly property var nextAction: () => {
                if (!introMessageInput.validate(true))
                    introMessageInput.input.dirty = true
                if (!outroMessageInput.validate(true))
                    outroMessageInput.input.dirty = true
                if (introMessageInput.valid && outroMessageInput.valid) {
                    if (root.isDiscordImport)
                        root.currentIndex++
                    else
                        d.createCommunity()
                }
            }

            IntroMessageInput {
                id: introMessageInput
                input.edit.objectName: "createCommunityIntroMessageInput"
                input.tabNavItem: outroMessageInput.input.edit

                Layout.fillWidth: true
                Layout.fillHeight: true

                label: qsTr("Community introduction and rules (you can edit this later)")
            }

            OutroMessageInput {
                id: outroMessageInput
                input.edit.objectName: "createCommunityOutroMessageInput"
                input.tabNavItem: introMessageInput.input.edit

                Layout.fillWidth: true
            }
        }
    ]

    QtObject {
        id: d

        function _getCommunityConfig() {
            return {
                name: StatusQUtils.Utils.filterXSS(generalViewLayout.name),
                description: StatusQUtils.Utils.filterXSS(generalViewLayout.description),
                introMessage: StatusQUtils.Utils.filterXSS(introMessageInput.input.text),
                outroMessage: StatusQUtils.Utils.filterXSS(outroMessageInput.input.text),
                color: generalViewLayout.color.toString().toUpperCase(),
                tags: generalViewLayout.selectedTags,
                image: {
                    src: generalViewLayout.logoImagePath,
                    AX: generalViewLayout.logoCropRect.x,
                    AY: generalViewLayout.logoCropRect.y,
                    BX: generalViewLayout.logoCropRect.x + generalViewLayout.logoCropRect.width,
                    BY: generalViewLayout.logoCropRect.y + generalViewLayout.logoCropRect.height,
                },
                options: {
                    historyArchiveSupportEnabled: generalViewLayout.options.archiveSupportEnabled,
                    checkedMembership: generalViewLayout.options.requestToJoinEnabled ? Constants.communityChatOnRequestAccess : Constants.communityChatPublicAccess,
                    pinMessagesAllowedForMembers: generalViewLayout.options.pinMessagesEnabled,
                    archiveSupporVisible: true
                },
                bannerJsonStr: Utils.getImageAndCropInfoJson(generalViewLayout.bannerPath, generalViewLayout.bannerCropRect)
            }
        }

        function createCommunity() {
            // Step 1: Proceed with community creation
            const error = root.store.createCommunity(_getCommunityConfig())
            if (error) {
                errorDialog.text = error.error
                errorDialog.open()
                return
            }
            // Step 2: Automatically set the archive protocol global property if it's been checked as
            // an option during community creation process. It's a more user friendly process
            else if(generalViewLayout.options.archiveSupportEnabled) {
                root.advancedStore.enableArchiveProtocolProperty()
            }

            root.close()
        }

        function requestImportDiscordCommunity() {
            const error = root.store.requestImportDiscordCommunity(_getCommunityConfig(), datePicker.selectedDate.valueOf()/1000)
            if (error) {
                errorDialog.text = error.error
                errorDialog.open()
            }
        }
    }

    StatusMessageDialog {
        id: errorDialog

        title: qsTr("Error creating the community")
        icon: StatusMessageDialog.StandardIcon.Critical
    }
}
