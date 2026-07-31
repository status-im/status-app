pragma ComponentBehavior: Bound

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

StatusAdaptiveStackDialog {
    id: root

    property CommunitiesStore store
    property AdvancedStore advancedStore
    property bool isDiscordImport // creating new or importing from discord?
    property bool isDevBuild

    defaultTitle: isDiscordImport ? qsTr("Import a community from Discord into Status") :
                                    qsTr("Create New Community")
    implicitWidth: 640
    maximumWidthOverride: 640
    initialItem: generalStepComponent
    customFooterRightButtons: footerRightButtonsModel
    showStackBackButton: !d.progressReplaceActive && (!!replaceItem || depth > 1)

    closeOnOverlayClick: false // explicit [x] click needed, or via the `close()` method
    escapeKeyCloses: false

    ObjectModel {
        id: footerRightButtonsModel

        StatusButton {
            text: qsTr("Clear all")
            type: StatusBaseButton.Type.Danger
            visible: root.currentItem && root.currentItem.objectName === "discordFileListView"
            enabled: d.fileListView && !d.fileListView.fileListModelEmpty && !root.store.discordDataExtractionInProgress
            onClicked: root.store.clearFileList()
        }

        StatusButton {
            objectName: "createCommunityNextBtn"
            visible: !root.replaceItem && !d.activeStepIsFinal
            text: root.currentItem && typeof root.currentItem.nextButtonText !== "undefined" ? root.currentItem.nextButtonText : qsTr("Next")
            enabled: !root.currentItem || typeof(root.currentItem.canGoNext) == "undefined" || root.currentItem.canGoNext
            loading: root.store.discordDataExtractionInProgress
            onClicked: {
                let nextAction = root.currentItem.nextAction
                if (typeof(nextAction) == "function") {
                    return nextAction()
                }
            }
        }

        StatusButton {
            objectName: "createCommunityFinalBtn"
            visible: !root.replaceItem && d.activeStepIsFinal
            text: root.isDiscordImport ? qsTr("Start Discord import") : qsTr("Create Community")
            enabled: !root.currentItem || typeof(root.currentItem.canGoNext) == "undefined" || root.currentItem.canGoNext
            onClicked: {
                let nextAction = root.currentItem.nextAction
                if (typeof (nextAction) == "function") {
                    return nextAction()
                }
            }
        }
    }

    onAboutToShow: {
        d.progressReplaceActive = false
        root.replace(null)
        root.resetStack(StackView.Immediate)
        root.backgroundColor = Theme.palette.statusModal.backgroundColor
        if (root.isDiscordImport && !root.store.discordImportInProgress) {
            root.store.clearFileList()
            root.store.clearDiscordCategoriesAndChannels()
        }
    }

    Component {
        id: discordFileListStepComponent

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
            readonly property bool isFinalStep: false
            readonly property var nextAction: function () {
                if (!fileListView.fileListModel.selectedFilesValid) {
                    return root.store.requestExtractChannelsAndCategories()
                }
                root.stack.push(discordCategoriesStepComponent)
            }

            Component.onCompleted: d.fileListView = fileListView
            Component.onDestruction: if (d.fileListView === fileListView)
                d.fileListView = null

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
        }
    }

    Component {
        id: discordCategoriesStepComponent

        ColumnLayout {
            id: categoriesAndChannelsView
            spacing: 24

            readonly property bool canGoNext: root.store.discordChannelsModel.hasSelectedItems
            readonly property bool isFinalStep: true
            readonly property var nextAction: function () {
                d.requestImportDiscordCommunity()
                // replace ourselves with the progress dialog, no way back
                d.progressReplaceActive = true
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

                Component.onCompleted: d.datePicker = datePicker
                Component.onDestruction: if (d.datePicker === datePicker)
                    d.datePicker = null

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
    }

    Component {
        id: generalStepComponent

        StatusScrollView {
            id: generalView
            contentWidth: availableWidth

            readonly property var nextAction: () => {
                if (generalViewLayout.validate(root.isDevBuild)) {
                    root.stack.push(introOutroStepComponent)
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

            Component.onCompleted: d.generalViewLayout = generalViewLayout
            Component.onDestruction: if (d.generalViewLayout === generalViewLayout)
                d.generalViewLayout = null
        }
    }

    Component {
        id: introOutroStepComponent

        ColumnLayout {
            id: introOutroMessageView
            spacing: Theme.padding

            readonly property bool isFinalStep: !root.isDiscordImport
            readonly property var nextAction: () => {
                if (!introMessageInput.validate(true))
                    introMessageInput.input.dirty = true
                if (!outroMessageInput.validate(true))
                    outroMessageInput.input.dirty = true
                if (introMessageInput.valid && outroMessageInput.valid) {
                    if (root.isDiscordImport)
                        root.stack.push(discordFileListStepComponent)
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

            Component.onCompleted: {
                d.introMessageInput = introMessageInput
                d.outroMessageInput = outroMessageInput
            }
            Component.onDestruction: {
                if (d.introMessageInput === introMessageInput)
                    d.introMessageInput = null
                if (d.outroMessageInput === outroMessageInput)
                    d.outroMessageInput = null
            }
        }
    }

    QtObject {
        id: d

        property var generalViewLayout
        property var introMessageInput
        property var outroMessageInput
        property var fileListView
        property var datePicker
        property bool progressReplaceActive: false

        readonly property bool activeStepIsFinal: root.currentItem && root.currentItem.isFinalStep

        function _getCommunityConfig() {
            return {
                name: StatusQUtils.Utils.filterXSS(d.generalViewLayout.name),
                description: StatusQUtils.Utils.filterXSS(d.generalViewLayout.description),
                introMessage: StatusQUtils.Utils.filterXSS(d.introMessageInput.input.text),
                outroMessage: StatusQUtils.Utils.filterXSS(d.outroMessageInput.input.text),
                color: d.generalViewLayout.color.toString().toUpperCase(),
                tags: d.generalViewLayout.selectedTags,
                image: {
                    src: d.generalViewLayout.logoImagePath,
                    AX: d.generalViewLayout.logoCropRect.x,
                    AY: d.generalViewLayout.logoCropRect.y,
                    BX: d.generalViewLayout.logoCropRect.x + d.generalViewLayout.logoCropRect.width,
                    BY: d.generalViewLayout.logoCropRect.y + d.generalViewLayout.logoCropRect.height,
                },
                options: {
                    historyArchiveSupportEnabled: d.generalViewLayout.options.archiveSupportEnabled,
                    checkedMembership: d.generalViewLayout.options.requestToJoinEnabled ? Constants.communityChatOnRequestAccess : Constants.communityChatPublicAccess,
                    pinMessagesAllowedForMembers: d.generalViewLayout.options.pinMessagesEnabled,
                    archiveSupporVisible: true
                },
                bannerJsonStr: JSON.stringify({imagePath: String(d.generalViewLayout.bannerPath).replace("file://", ""), cropRect: d.generalViewLayout.bannerCropRect})
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
            else if(d.generalViewLayout.options.archiveSupportEnabled) {
                root.advancedStore.enableArchiveProtocolProperty()
            }

            root.close()
        }

        function requestImportDiscordCommunity() {
            const error = root.store.requestImportDiscordCommunity(_getCommunityConfig(), d.datePicker.selectedDate.valueOf()/1000)
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
