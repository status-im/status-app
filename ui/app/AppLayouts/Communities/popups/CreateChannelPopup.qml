pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQml
import QtQml.Models

import utils
import shared.panels

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Controls
import StatusQ.Controls.Validators
import StatusQ.Components
import StatusQ.Popups
import StatusQ.Popups.Dialog

import AppLayouts.Communities.views
import AppLayouts.Communities.panels
import AppLayouts.Communities.models
import AppLayouts.Communities.controls
import AppLayouts.Communities.stores as CommunitiesStores
import AppLayouts.Wallet.stores

StatusAdaptiveStackDialog {
    id: root

    property CommunitiesStores.CommunitiesStore communitiesStore
    property TokensStore tokensStore

    property bool isDiscordImport // creating new or importing from discord?
    property bool isEdit: false
    property bool isDeleteable: false
    property bool viewOnlyCanAddReaction
    property bool hideIfPermissionsNotMet: false
    property bool ensCommunityPermissionsEnabled: false

    property string communityId: ""
    property string chatId: "_newChannel"

    property string categoryId: ""
    property string channelName: ""
    property string channelDescription: ""
    property string channelEmoji: ""
    property string channelColor: d.communityDetails.color !== "" ? d.communityDetails.color : ""
    property bool emojiPopupOpened: false
    property var emojiPopup: null
    readonly property int communityColorValidator: Utils.Validate.NoEmpty
                                                   | Utils.Validate.TextHexColor

    property var activeCommunity
    required property var assetsModel
    property bool assetsLoading: false
    property var loadTokenList: function() {}
    required property var collectiblesModel
    required property var permissionsModel

    required property var channelsModel

    readonly property int maxChannelNameLength: 24
    readonly property int maxChannelDescLength: 140

    // channel signals
    signal createCommunityChannel(string chName, string chDescription, string chEmoji, string chColor, string chCategoryId, bool viewOnlyCanAddReaction, bool hideIfPermissionsNotMet)
    signal editCommunityChannel(string chName, string chDescription, string chEmoji, string chColor, string chCategoryId, bool viewOnlyCanAddReaction, bool hideIfPermissionsNotMet)
    signal deleteCommunityChannel()

    // Permissions signals:
    // permissions arg is a list of objects with the following properties:
    // - key: string
    // - id: string
    // - permissionType: string
    // - holdings: list of objects with the following properties:
    //   - key: string
    //   - type: string
    //   - amount: string
    // - channels: list of objects with the following properties:
    //   - key: string
    // - isPrivate: bool
    signal addPermissions(var permissions)
    signal removePermissions(var permissions)
    signal editPermissions(var permissions)

    implicitWidth: 640
    maximumWidthOverride: 640
    contentLeftPaddingOverride: 0
    contentRightPaddingOverride: 0
    initialItem: channelDetailsStepComponent
    customFooterLeftButtons: footerLeftButtonsModel
    customFooterRightButtons: footerRightButtonsModel
    closeOnOverlayClick: !(d.dirty && !root.isDiscordImport)
    escapeKeyCloses: !(d.dirty && !root.isDiscordImport)
    closeHandler: d.closeRequested
    
    enum CurrentPage {
        ChannelDetails, //0
        ColorPicker, //1
        ChannelPermissions, //2
        DiscordImportUploadFile, //3
        DiscordImportUploadStart //4
    }

    QtObject {
        id: d

        property var nameInput
        property var descriptionTextArea
        property var colorPanel
        property var scrollView
        property var datePicker
        property var fileListViewItem
        property var editPermissionView
        property var pendingPermissionProperties: null
        property bool progressReplaceActive: false
        property color selectedChannelColor: root.channelColor || Theme.palette.primaryColor1
        property bool selectedChannelColorSet: !!root.channelColor && root.channelColor != Theme.palette.primaryColor1

        readonly property bool detailsReady: !!d.nameInput && !!d.descriptionTextArea
        readonly property bool dirty: d.detailsReady && (d.channelEditModel.dirtyPermissions ||
                                    d.viewOnlyCanAddReaction !== root.viewOnlyCanAddReaction ||
                                    d.hideIfPermissionsNotMet !== root.hideIfPermissionsNotMet ||
                                    d.nameInput.input.text !== root.channelName ||
                                    d.descriptionTextArea.text !== root.channelDescription ||
                                    !Qt.colorEqual(d.selectedChannelColor, root.channelColor) ||
                                    d.nameInput.input.asset.emoji !== root.channelEmoji)

        property int currentPage: CreateChannelPopup.CurrentPage.ChannelDetails

        readonly property QtObject communityDetails: QtObject {
            readonly property string id: root.activeCommunity.id
            readonly property string name: root.activeCommunity.name
            readonly property string image: root.activeCommunity.image
            readonly property string color: root.activeCommunity.color
            readonly property bool owner: root.activeCommunity.memberRole === Constants.memberRole.owner
            readonly property bool admin: root.activeCommunity.memberRole === Constants.memberRole.admin
            readonly property bool tokenMaster: root.activeCommunity.memberRole === Constants.memberRole.tokenMaster
        }

        readonly property ChannelPermissionsModelEditor channelEditModel: ChannelPermissionsModelEditor {
            channelId: root.chatId
            name: d.nameInput ? d.nameInput.input.text : ""
            emoji: d.nameInput ? d.nameInput.input.asset.emoji : ""
            color: d.selectedChannelColor.toString().toUpperCase()
            channelsModel: root.channelsModel
            permissionsModel: root.permissionsModel
            newChannelMode: !root.isEdit

            property Connections rootConnection: Connections {
                target: root
                function onClosed() {
                    d.channelEditModel.reset()
                }
            }
        }
        
        property bool viewOnlyCanAddReaction: root.viewOnlyCanAddReaction
        property bool hideIfPermissionsNotMet: root.hideIfPermissionsNotMet
        property bool colorPickerOpened: false
        readonly property bool activeStepIsFinal: root.currentItem && root.currentItem.isFinalStep

        function openPage(page) {
            if (!root.stack)
                return

            switch (page) {
            case CreateChannelPopup.CurrentPage.ColorPicker:
                root.stack.push(colorPanelStepComponent)
                d.colorPickerOpened = true
                break
            case CreateChannelPopup.CurrentPage.ChannelPermissions:
                root.stack.push(channelPermissionsStepComponent)
                d.colorPickerOpened = false
                break
            case CreateChannelPopup.CurrentPage.DiscordImportUploadFile:
                root.stack.push(discordFileListStepComponent)
                d.colorPickerOpened = false
                break
            case CreateChannelPopup.CurrentPage.DiscordImportUploadStart:
                root.stack.push(discordImportStartStepComponent)
                d.colorPickerOpened = false
                break
            default:
                root.stack.popToIndex(0)
                d.colorPickerOpened = false
                break
            }

            d.currentPage = page
        }

        function returnToDetails() {
            if (root.stack)
                root.stack.popToIndex(0)
            d.currentPage = CreateChannelPopup.CurrentPage.ChannelDetails
            d.colorPickerOpened = false
        }

        function goBack() {
            if (d.currentPage === CreateChannelPopup.CurrentPage.DiscordImportUploadStart) {
                root.stack.popCurrentItem()
                d.currentPage = CreateChannelPopup.CurrentPage.DiscordImportUploadFile
                return
            }

            d.returnToDetails()
        }

        function openPermissionEditor(properties) {
            d.pendingPermissionProperties = properties
            d.openPage(CreateChannelPopup.CurrentPage.ChannelPermissions)
        }

        function isFormValid() {
            return d.detailsReady && d.nameInput.valid && d.descriptionTextArea.valid &&
                    Utils.validateAndReturnError(d.selectedChannelColor.toString().toUpperCase(), communityColorValidator) === ""
        }

        function openEmojiPopup(leftSide = false) {
            root.emojiPopupOpened = true;
            root.emojiPopup.open();
            root.emojiPopup.emojiSize = StatusQUtils.Emoji.size.verySmall;
            root.emojiPopup.directParent = d.nameInput
            root.emojiPopup.relativeX = leftSide ? 0 : d.nameInput.width - root.emojiPopup.width
            root.emojiPopup.relativeY = d.nameInput.height + Theme.smallPadding;
        }

        function _getChannelConfig() {
            return {
                communityId: root.communityId,
                discordChannelId: root.communitiesStore.discordImportChannelId,
                categoryId: root.categoryId,
                name: StatusQUtils.Utils.filterXSS(d.nameInput.input.text),
                description: StatusQUtils.Utils.filterXSS(d.descriptionTextArea.text),
                color: d.selectedChannelColor.toString().toUpperCase(),
                emoji: StatusQUtils.Emoji.deparse(d.nameInput.input.asset.emoji),
                options: {
                    // TODO
                }
            }
        }

        function requestImportDiscordChannel() {
            const error = root.communitiesStore.requestImportDiscordChannel(_getChannelConfig(), d.datePicker.selectedDate.valueOf()/1000)
            if (error) {
                creatingError.text = error.error
                creatingError.open()
            }
        }

        function saveAndClose() {
            if (!d.isFormValid()) {
                d.scrollView.scrollBackUp()
                return
            }
            let emoji = StatusQUtils.Emoji.deparse(d.nameInput.input.asset.emoji)
            if (!isEdit) {
                root.createCommunityChannel(StatusQUtils.Utils.filterXSS(d.nameInput.input.text),
                                            StatusQUtils.Utils.filterXSS(d.descriptionTextArea.text),
                                            emoji,
                                            d.selectedChannelColor.toString().toUpperCase(),
                                            root.categoryId,
                                            d.viewOnlyCanAddReaction,
                                            d.hideIfPermissionsNotMet)
            } else {
                root.editCommunityChannel(StatusQUtils.Utils.filterXSS(d.nameInput.input.text),
                                            StatusQUtils.Utils.filterXSS(d.descriptionTextArea.text),
                                            emoji,
                                            d.selectedChannelColor.toString().toUpperCase(),
                                            root.categoryId,
                                            d.viewOnlyCanAddReaction,
                                            d.hideIfPermissionsNotMet)
            }

            if (d.channelEditModel.dirtyPermissions) {
                var newPermissions = d.channelEditModel.getAddedPermissions();
                if (newPermissions.length > 0) {
                    root.addPermissions(newPermissions);
                }

                var editedPermissions = d.channelEditModel.getEditedPermissions();
                if (editedPermissions.length > 0) {
                    root.editPermissions(editedPermissions);
                }

                var removedPermissions = d.channelEditModel.getRemovedPermissions();
                if (removedPermissions.length > 0) {
                    root.removePermissions(removedPermissions);
                }
            }

            // TODO Open the channel once we have designs for it
            root.close()
        }

        function closeRequested() {
            if (d.dirty && !root.isDiscordImport)
                closeConfirmation.open()
            else
                root.close()
        }
    }

    StatusConfirmationDialog {
        id: closeConfirmation
        title: qsTr("Save changes to #%1 channel?").arg(root.channelName || (d.nameInput ? d.nameInput.input.text : ""))
        body: qsTr("You have made changes to #%1 channel. If you close this dialog without saving these changes will be lost?").arg(root.channelName || (d.nameInput ? d.nameInput.input.text : ""))
        acceptButtonText: qsTr("Save changes")
        rejectButtonText: qsTr("Close without saving")
        onAccepted: {
            d.saveAndClose()
        }
        onRejected: {
            root.close()
        }
    }

    defaultTitle: isDiscordImport ? qsTr("New Channel With Imported Chat History") :
                                    (isEdit ? qsTr("Edit #%1").arg(root.channelName) : qsTr("New channel"))

    ObjectModel {
        id: footerLeftButtonsModel

        StatusBackButton {
            visible: d.currentPage !== CreateChannelPopup.CurrentPage.ChannelDetails && !d.progressReplaceActive
            onClicked: d.goBack()

            Layout.minimumWidth: implicitWidth
        }
    }

    ObjectModel {
        id: footerRightButtonsModel

        StatusButton {
            text: qsTr("Clear all")
            type: StatusBaseButton.Type.Danger
            visible: root.currentItem && typeof root.currentItem.isFileListView !== "undefined" && root.currentItem.isFileListView
            enabled: d.fileListViewItem && !d.fileListViewItem.fileListModelEmpty && !root.communitiesStore.discordDataExtractionInProgress
            onClicked: root.communitiesStore.clearFileList()
        }

        StatusButton {
            objectName: "deleteCommunityChannelBtn"
            height: 44
            visible: isEdit && isDeleteable && !isDiscordImport && (d.currentPage === CreateChannelPopup.CurrentPage.ChannelDetails) ||
                     !!(root.currentItem && root.currentItem.deleteButtonText)
            text: (d.currentPage === CreateChannelPopup.CurrentPage.ChannelPermissions) ? root.currentItem.deleteButtonText : qsTr("Delete channel")
            enabled: (d.currentPage === CreateChannelPopup.CurrentPage.ChannelPermissions) ? root.currentItem.deleteButtonEnabled : true
            type: StatusBaseButton.Type.Danger
            onClicked: {
                const nextAction = root.currentItem.nextDeleteAction
                if (typeof(nextAction) == "function") {
                    return nextAction()
                } else {
                    root.deleteCommunityChannel();
                }
            }
        }

        StatusButton {
            objectName: "createOrEditCommunityChannelBtn"
            visible: !d.colorPickerOpened && !d.activeStepIsFinal && !root.replaceItem
            enabled: !root.currentItem || typeof(root.currentItem.canGoNext) == "undefined" || root.currentItem.canGoNext
            text: root.currentItem && !!root.currentItem.nextButtonText ? root.currentItem.nextButtonText :
                                                                    isDiscordImport ? qsTr("Import chat history") :
                                                                                      isEdit ? qsTr("Save changes") : qsTr("Create channel")
            loading: root.communitiesStore.discordDataExtractionInProgress
            onClicked: {
                let nextAction = root.currentItem.nextAction
                if (typeof (nextAction) == "function") {
                    return nextAction()
                }
            }
        }

        StatusButton {
            objectName: "createChannelNextBtn"
            visible: !root.replaceItem && d.activeStepIsFinal
            text: (root.currentItem && typeof root.currentItem.nextButtonText !== "undefined") ? root.currentItem.nextButtonText :
                                                                        qsTr("Import chat history")
            enabled: !root.currentItem || typeof(root.currentItem.canGoNext) == "undefined" || root.currentItem.canGoNext
            onClicked: {
                const nextAction = root.currentItem.nextAction
                if (typeof(nextAction) == "function") {
                    return nextAction()
                }
            }
        }
    }

    onAboutToShow: {
        d.progressReplaceActive = false
        root.replace(null)
        root.backgroundColor = Theme.palette.statusModal.backgroundColor
        d.selectedChannelColor = root.channelColor || Theme.palette.primaryColor1
        d.selectedChannelColorSet = !!root.channelColor && root.channelColor != Theme.palette.primaryColor1
        d.returnToDetails()

        if (root.isDiscordImport) {
            if (!root.communitiesStore.discordImportInProgress) {
                root.communitiesStore.clearFileList()
                root.communitiesStore.clearDiscordCategoriesAndChannels()
            }
        }
    }

    onOpened: {
        if (!d.nameInput || !d.descriptionTextArea)
            return

        d.nameInput.input.edit.forceActiveFocus(Qt.MouseFocusReason)
        if (isEdit) {
            d.nameInput.text = root.channelName
            d.descriptionTextArea.text = root.channelDescription
            if (root.channelEmoji) {
                d.nameInput.input.asset.emoji = root.channelEmoji
            }
        } else {
            d.nameInput.input.asset.isLetterIdenticon = true;
        }
    }

    Component {
        id: discordFileListStepComponent

        Item {
            id: fileListViewItem
            readonly property bool isFileListView: true

            readonly property var fileListModel: root.communitiesStore.discordFileList
            readonly property bool fileListModelEmpty: !fileListModel.count

            readonly property bool canGoNext: fileListModel.selectedCount
                                              || (fileListModel.selectedCount && fileListModel.selectedFilesValid)
            readonly property string nextButtonText: fileListModel.selectedCount && fileListModel.selectedFilesValid ?
                                                         qsTr("Proceed with (%1/%2) files").arg(fileListModel.selectedCount).arg(fileListModel.count) :
                                                         fileListModel.selectedCount && fileListModel.selectedCount === fileListModel.count ? qsTr("Validate %n file(s)", "", fileListModel.selectedCount)
                                                                                                                                            : fileListModel.selectedCount ? qsTr("Validate (%1/%2) files").arg(fileListModel.selectedCount).arg(fileListModel.count)
                                                                                                                                                                          : qsTr("Start channel import")
            readonly property var nextAction: function () {
                if (!fileListViewItem.fileListModel.selectedFilesValid)
                    return root.communitiesStore.requestExtractChannelsAndCategories()

                d.openPage(CreateChannelPopup.CurrentPage.DiscordImportUploadStart);
            }

            Component.onCompleted: d.fileListViewItem = fileListViewItem
            Component.onDestruction: if (d.fileListViewItem === fileListViewItem)
                d.fileListViewItem = null

            ColumnLayout {
                id: fileListView
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 24

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    StatusBaseText {
                        Layout.fillWidth: true
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        text: fileListViewItem.fileListModelEmpty ? qsTr("Select Discord channel JSON files to import") :
                                                                root.communitiesStore.discordImportErrorsCount ? qsTr("Some of your community files cannot be used") :
                                                                                                                 qsTr("Uncheck any files you would like to exclude from the import")
                    }
                    StatusBaseText {
                        visible: fileListViewItem.fileListModelEmpty && !issuePill.visible
                        font.pixelSize: Theme.tertiaryTextFontSize
                        color: Theme.palette.baseColor1
                        text: qsTr("(JSON file format only)")
                    }
                    IssuePill {
                        id: issuePill
                        type: root.communitiesStore.discordImportErrorsCount ? IssuePill.Type.Error : IssuePill.Type.Warning
                        count: root.communitiesStore.discordImportErrorsCount || root.communitiesStore.discordImportWarningsCount || 0
                        visible: !!count && !fileListViewItem.fileListModelEmpty
                    }
                    StatusButton {
                        Layout.alignment: Qt.AlignRight
                        text: qsTr("Browse files")
                        type: StatusBaseButton.Type.Primary
                        onClicked: fileDialog.open()
                        enabled: !root.communitiesStore.discordDataExtractionInProgress
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.palette.baseColor4

                    ColumnLayout {
                        visible: fileListViewItem.fileListModelEmpty
                        anchors.top: parent.top
                        anchors.topMargin: 60
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        StatusRoundIcon {
                            Layout.alignment: Qt.AlignHCenter
                            asset.name: "info"
                        }
                        StatusBaseText {
                            id: infoText1
                            Layout.topMargin: 8
                            Layout.alignment: Qt.AlignHCenter
                            horizontalAlignment: Qt.AlignHCenter
                            text: qsTr("Export the Discord channel’s chat history data using %1").arg("<a href='https://github.com/Tyrrrz/DiscordChatExporter/releases/tag/2.40.4'>DiscordChatExporter</a>")
                            onLinkActivated: (link) => Global.requestOpenLink(link)
                            StatusMouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                            }
                        }
                        StatusBaseText {
                            id: infoText2
                            Layout.alignment: Qt.AlignHCenter
                            horizontalAlignment: Qt.AlignHCenter
                            text: qsTr("Refer to this <a href='https://github.com/Tyrrrz/DiscordChatExporter/blob/master/.docs/Readme.md'>documentation</a> if you have any queries")
                            onLinkActivated: (link) => Global.requestOpenLink(link)
                            StatusMouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                            }
                        }
                    }

                    Component {
                        id: floatingDivComp
                        Rectangle {
                            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                            width: ListView.view ? ListView.view.width : 0
                            height: 4
                            color: Theme.palette.directColor8
                        }
                    }

                    StatusListView {
                        visible: !fileListViewItem.fileListModelEmpty
                        enabled: !root.communitiesStore.discordDataExtractionInProgress
                        anchors.fill: parent
                        leftMargin: 8
                        rightMargin: 8
                        model: fileListViewItem.fileListModel
                        header: !atYBeginning ? floatingDivComp : null
                        headerPositioning: ListView.OverlayHeader
                        footer: !atYEnd ? floatingDivComp : null
                        footerPositioning: ListView.OverlayHeader
                        delegate: ColumnLayout {
                            width: ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin
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
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    type: StatusFlatRoundButton.Type.Secondary
                                    icon.name: "close"
                                    icon.color: Theme.palette.directColor1
                                    icon.width: 24
                                    icon.height: 24
                                    onClicked: root.communitiesStore.removeFileListItem(model.filePath)
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
            }
            StatusFileDialog {
                id: fileDialog
                title: qsTr("Choose files to import")
                selectMultiple: true
                nameFilters: [qsTr("JSON files (%1)").arg("*.json *.JSON")]
                onAccepted: {
                    if(fileDialog.selectedFiles.length === 0) {
                        return
                    }
                    else if (fileDialog.selectedFiles.length > 0) {
                        const files = []
                        for (let i = 0; i < fileDialog.selectedFiles.length; i++)
                            files.push(decodeURI(fileDialog.selectedFiles[i].toString()))
                        root.communitiesStore.setFileListItems(files)
                    }
                }
            }
        }
    }

    Component {
        id: discordImportStartStepComponent

        Item {
            readonly property bool canGoNext: root.communitiesStore.discordChannelsModel.hasSelectedItems
            readonly property bool isFinalStep: true
            readonly property var nextAction: function () {
                d.requestImportDiscordChannel()
                // replace ourselves with the progress dialog, no way back
                d.progressReplaceActive = true
                root.backgroundColor = Theme.palette.baseColor4
                root.replace(progressComponent)
            }

            ColumnLayout {
                id: categoriesAndChannelsView
                spacing: 24
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16

                Component {
                    id: progressComponent
                    DiscordImportProgressContents {
                        width: root.availableWidth
                        store: root.communitiesStore
                        importingSingleChannel: true
                        onClose: root.close()
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: !root.communitiesStore.discordChannelsModel.count
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
                    visible: root.communitiesStore.discordChannelsModel.count

                    StatusBaseText {
                        Layout.fillWidth: true
                        text: qsTr("Select the chat history you would like to import into #%1...").arg(StatusQUtils.Utils.filterXSS(d.nameInput.input.text))
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
                            selectedDate: new Date(root.communitiesStore.discordOldestMessageTimestamp * 1000)
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
                            model: root.communitiesStore.discordCategoriesModel
                            delegate: ColumnLayout {
                                width: ListView.view.width
                                spacing: 8

                                StatusBaseText {
                                    readonly property string categoryId: model.id
                                    id: categoryCheckbox
                                    text: model.name
                                }

                                ColumnLayout {
                                    spacing: 8
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 24
                                    Repeater {
                                        Layout.fillWidth: true
                                        model: root.communitiesStore.discordChannelsModel
                                        delegate: StatusRadioButton {
                                            width: parent.width
                                            text: model.name
                                            checked: model.selected
                                            visible: model.categoryId === categoryCheckbox.categoryId
                                            onToggled: root.communitiesStore.toggleOneDiscordChannel(model.id)
                                            Component.onCompleted: {
                                                if (model.selected) {
                                                    root.communitiesStore.toggleOneDiscordChannel(model.id)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        enabled: root.opened && root.emojiPopupOpened
        target: emojiPopup

        function onEmojiSelected(emojiText: string, atCursor: bool) {
            d.nameInput.input.asset.isLetterIdenticon = false;
            d.nameInput.input.asset.emoji = emojiText
        }
        function onClosed() {
            root.emojiPopupOpened = false
        }
    }

    Component {
        id: channelDetailsStepComponent

        StatusScrollView {
            id: scrollView

            readonly property bool canGoNext: d.isFormValid() && (root.isDiscordImport ? true : d.dirty)

            property ScrollBar vScrollBar: ScrollBar.vertical

            contentWidth: availableWidth
            padding: 0

            function scrollBackUp() {
                vScrollBar.setPosition(0)
            }

            ColumnLayout {
                id: content
                width: scrollView.availableWidth
                spacing: Theme.padding
                StatusInput {
                    id: nameInput
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padding
                    Layout.rightMargin: Theme.padding
                    input.edit.objectName: "createOrEditCommunityChannelNameInput"
                    label: qsTr("Channel name")
                    charLimit: root.maxChannelNameLength
                    placeholderText: qsTr("# Name the channel")
                    input.onTextChanged: {
                        const cursorPosition = input.cursorPosition
                        input.text = Utils.convertSpacesToDashes(input.text)
                        input.cursorPosition = cursorPosition
                        if (root.channelEmoji === "") {
                            input.letterIconName = text
                        }
                    }
                    input.asset.color: d.selectedChannelColor
                    input.rightComponent: StatusRoundButton {
                        objectName: "StatusChannelPopup_emojiButton"
                        implicitWidth: 32
                        implicitHeight: 32
                        icon.width: 20
                        icon.height: 20
                        icon.name: "smiley"
                        onClicked: d.openEmojiPopup()
                    }
                    onIconClicked: {
                        d.openEmojiPopup(true);
                    }

                    validators: [
                        StatusMinLengthValidator {
                            minLength: 1
                            errorMessage: Utils.getErrorMessage(nameInput.errors, qsTr("channel name"))
                        },
                        StatusRegularExpressionValidator {
                            regularExpression: Constants.regularExpressions.alphanumericalExpanded
                            errorMessage: qsTr("Only letters, numbers, underscores, periods and hyphens allowed")
                        }
                    ]
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82
                    Layout.leftMargin: Theme.padding
                    Layout.rightMargin: Theme.padding
                    StatusBaseText {
                        width: parent.width
                        anchors.top: parent.top
                        anchors.topMargin: Theme.halfPadding
                        text: qsTr("Channel colour")
                    }
                    StatusPickerButton {
                        id: colorSelectorButton

                        property string validationError: ""
                        width: parent.width
                        height: 44
                        anchors.bottom: parent.bottom
                        bgColor: d.selectedChannelColorSet ? d.selectedChannelColor : Theme.palette.baseColor2
                        contentColor: d.selectedChannelColorSet ? StatusColors.white : Theme.palette.baseColor1
                        text: d.selectedChannelColorSet ? d.selectedChannelColor.toString().toUpperCase() : qsTr("Pick a colour")
                        onClicked: d.openPage(CreateChannelPopup.CurrentPage.ColorPicker)
                        onTextChanged: {
                            if (d.selectedChannelColorSet) {
                                validationError = Utils.validateAndReturnError(text, communityColorValidator)
                            }
                        }
                    }
                }

                StatusInput {
                    id: descriptionTextArea
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.halfPadding
                    Layout.leftMargin: Theme.padding
                    Layout.rightMargin: Theme.padding
                    input.edit.objectName: "createOrEditCommunityChannelDescriptionInput"
                    input.verticalAlignment: TextEdit.AlignTop
                    label: qsTr("Description")
                    charLimit: 140
                    placeholderText: qsTr("Describe the channel")
                    input.multiline: true
                    minimumHeight: 108
                    maximumHeight: 108
                    validators: [
                        StatusMinLengthValidator {
                            minLength: 1
                            errorMessage: Utils.getErrorMessage(descriptionTextArea.errors, qsTr("channel description"))
                        },
                        StatusRegularExpressionValidator {
                            regularExpression: Constants.regularExpressions.alphanumericalExpanded3
                            errorMessage: Constants.errorMessages.alphanumericalExpandedRegExp
                        }
                    ]
                }
                Separator { 
                    Layout.fillWidth: true
                    visible: viewOnlyCanAddReactionCheckbox.visible
                }
                StatusCheckBox {
                    objectName: "hideChannelCheckbox"
                    id: viewOnlyCanAddReactionCheckbox
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    Layout.leftMargin: Theme.padding
                    Layout.rightMargin: Theme.padding
                    leftSide: false
                    text: qsTr("Hide channel from members who don't have permissions to view the channel")
                    checked: d.hideIfPermissionsNotMet
                    onToggled: {
                        d.hideIfPermissionsNotMet = checked;
                    }
                }
                Separator {
                    Layout.fillWidth: true
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    Layout.leftMargin: Theme.padding
                    Layout.rightMargin: Theme.padding
                    StatusBaseText {
                        text: qsTr("Permissions")
                    }
                    Item { Layout.fillWidth: true }
                    StatusButton {
                        objectName: "addPermissionButton"
                        text: qsTr("Add permission")
                        enabled: !!nameInput.text
                        property ListModel channelToAddPermission: ListModel { }
                        onClicked: {
                            channelToAddPermission.clear();
                            channelToAddPermission.append({"key": root.chatId, "name": nameInput.text});
                            const properties = {
                                channelsToEditModel: channelToAddPermission,
                                header: null,
                                topPadding: -root.subHeaderPadding - 8,
                                leftPadding: 0,
                                viewWidth: scrollView.availableWidth - 32
                            };
                            d.openPermissionEditor(properties);
                        }
                    }
                }
                PermissionsView {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignBottom
                    Layout.leftMargin: Theme.padding
                    Layout.rightMargin: Theme.padding

                    preferredContentWidth: scrollView.availableWidth
                    internalRightPadding: 0

                    permissionsModel: d.channelEditModel.channelPermissionsModel
                    assetsModel: root.assetsModel
                    collectiblesModel: root.collectiblesModel

                    getTokenByKeyOrGroupKeyFromAllTokens: root.tokensStore.getTokenByKeyOrGroupKeyFromAllTokens

                    viewOnlyCanAddReaction: root.viewOnlyCanAddReaction
                    channelsModel: d.channelEditModel.liveChannelsModel
                    communityDetails: d.communityDetails
                    showChannelOptions: true
                    allowIntroPanel: false
                    onRemovePermissionRequested: {
                        console.assert(d.channelEditModel.removePermission(index))
                    }
                    onDuplicatePermissionRequested: {
                        const item = StatusQUtils.ModelUtils.get(d.channelEditModel.channelPermissionsModel, index);
                        const properties = {
                            holdingsToEditModel: item.holdingsListModel,
                            channelsToEditModel: item.channelsListModel,
                            permissionTypeToEdit: item.permissionType,
                            isPrivateToEditValue: item.isPrivate,
                            header: null,
                            topPadding: -root.subHeaderPadding - 8,
                            leftPadding: 0,
                            rightPadding: 16,
                            viewWidth: scrollView.availableWidth - 32
                        }
                        properties.resetOnOpen = true
                        d.openPermissionEditor(properties);
                    }

                    onEditPermissionRequested: {
                        const item = d.channelEditModel.channelPermissionsModel.get(index);
                        const requireHoldings = (item.holdingsListModel.count ?? item.holdingsListModel.rowCount()) > 0;
                        const properties = {
                            permissionKeyToEdit: item.key,
                            holdingsToEditModel: item.holdingsListModel,
                            channelsToEditModel: item.channelsListModel,
                            permissionTypeToEdit: item.permissionType,
                            isPrivateToEditValue: item.isPrivate,
                            header: null,
                            topPadding: -root.subHeaderPadding - 8,
                            leftPadding: 0,
                            rightPadding: 16,
                            viewWidth: scrollView.availableWidth - 32
                        }
                        properties.resetOnOpen = true
                        d.openPermissionEditor(properties);
                    }
                    onUserRestrictionsToggled: {
                        d.viewOnlyCanAddReaction = checked;
                    }
                }
            }
            readonly property var nextAction: function () {
                if (!root.isDiscordImport) {
                    d.saveAndClose()
                } else {
                    d.openPage(CreateChannelPopup.CurrentPage.DiscordImportUploadFile);
                }
            }
            Component.onCompleted: {
                d.scrollView = scrollView
                d.nameInput = nameInput
                d.descriptionTextArea = descriptionTextArea
            }
            Component.onDestruction: {
                if (d.scrollView === scrollView)
                    d.scrollView = null
                if (d.nameInput === nameInput)
                    d.nameInput = null
                if (d.descriptionTextArea === descriptionTextArea)
                    d.descriptionTextArea = null
            }
        }
    }

    Component {
        id: colorPanelStepComponent

        ColorPanel {
            id: colorPanel
            readonly property string stackTitleText: qsTr("Channel Colour")
            readonly property string nextButtonText: qsTr("Select Channel Colour")
            padding: 0
            leftPadding: 16
            rightPadding: 16
            height: Math.min(parent.height, 624)
            property bool colorSelected: d.selectedChannelColorSet
            color: d.selectedChannelColor
            onAccepted: {
                d.selectedChannelColor = color
                d.selectedChannelColorSet = true
                d.returnToDetails();
            }
            readonly property var nextAction: function () {
                accepted();
            }
            Component.onCompleted: d.colorPanel = colorPanel
            Component.onDestruction: if (d.colorPanel === colorPanel)
                d.colorPanel = null
        }
    }

    Component {
        id: channelPermissionsStepComponent

        PermissionsSettingsPanel {
            id: editPermissionView

            leftPadding: 16
            rightPadding: 16
            initialPage.header: null
            initialPage.topPadding: 0
            initialPage.leftPadding: 0

            preferredContentWidth: width
            internalRightPadding: 0

            assetsModel: root.assetsModel
            assetsLoading: root.assetsLoading
            loadTokenList: root.loadTokenList
            collectiblesModel: root.collectiblesModel
            permissionsModel: d.channelEditModel.channelPermissionsModel
            channelsModel: d.channelEditModel.liveChannelsModel
            communityDetails: d.communityDetails
            showChannelSelector: false
            ensCommunityPermissionsEnabled: root.ensCommunityPermissionsEnabled

            getTokenByKeyOrGroupKeyFromAllTokens: root.tokensStore.getTokenByKeyOrGroupKeyFromAllTokens

            readonly property string nextButtonText: !!currentItem.permissionKeyToEdit ?
                                                         qsTr("Update permission") : qsTr("Create permission")
            readonly property string stackTitleText: !!currentItem.permissionKeyToEdit ?
                                                         qsTr("Edit #%1 permission").arg(d.nameInput.text) : qsTr("New #%1 permission").arg(d.nameInput.text)
            readonly property string deleteButtonText: !!currentItem.permissionKeyToEdit ?
                                                           qsTr("Revert changes") : ""
            readonly property bool canGoNext: !!currentItem && !!currentItem.isSaveEnabled ? currentItem.isSaveEnabled : false

            readonly property bool deleteButtonEnabled: editPermissionView.canGoNext
            
            readonly property var nextDeleteAction: function () {
                if (!!currentItem.permissionKeyToEdit) {
                    currentItem.resetChanges();
                }
            }
            readonly property var nextAction: function () {
                if (!!currentItem.permissionKeyToEdit) {
                    currentItem.updatePermission();
                } else {
                    currentItem.createPermission();
                }
            }
            onCreatePermissionRequested: {
                d.channelEditModel.appendPermission(holdings, channels, permissionType, isPrivate)
                d.returnToDetails();
            }

            onUpdatePermissionRequested: {
                d.channelEditModel.editPermission(key, permissionType, holdings, channels, isPrivate)
                d.returnToDetails();
            }

            Component.onCompleted: {
                d.editPermissionView = editPermissionView
                if (d.pendingPermissionProperties) {
                    const resetOnOpen = d.pendingPermissionProperties.resetOnOpen
                    delete d.pendingPermissionProperties.resetOnOpen
                    editPermissionView.pushEditView(d.pendingPermissionProperties)
                    if (resetOnOpen)
                        editPermissionView.currentItem.resetChanges()
                    d.pendingPermissionProperties = null
                }
            }
            Component.onDestruction: if (d.editPermissionView === editPermissionView)
                d.editPermissionView = null
        }
    }

    StatusMessageDialog {
        id: creatingError
        title: qsTr("Error creating the channel")
        icon: StatusMessageDialog.StandardIcon.Critical
    }
}
