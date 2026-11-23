pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import AppLayouts.Chat.popups

import utils

RowLayout {
    id: root

    required property string threadId
    required property string threadName
    required property string parentChatName
    required property bool canEdit
    property string threadLinkToCopyShare: ""
    required property bool pending
    property bool deletePending: false
    property bool followed: false

    readonly property bool editing: d.editing
    readonly property StatusTextArea editor: inputLoader.status === Loader.Ready
                                             ? inputLoader.item as StatusTextArea : null

    property bool muted: false
    signal muteRequested(int interval)
    signal unmuteRequested()
    signal renameRequested(string name)
    signal editNameRequested()
    signal markAsReadRequested()
    signal deleteRequested()
    signal followRequested()
    signal unfollowRequested()

    function deleteFinished(error: string) {
        if (error)
            d.error = qsTr("Couldn't delete thread: %1").arg(error)
    }

    function beginEditing() {
        if (!root.canEdit || root.pending || root.deletePending)
            return
        d.draft = root.threadName
        d.error = ""
        d.editing = true
        if (root.editor)
            root.editor.forceActiveFocus(Qt.OtherFocusReason)
    }

    function editFinished(error: string) {
        if (!d.submitted)
            return
        d.submitted = false
        if (!error) {
            d.editing = false
            d.error = ""
        } else {
            d.error = qsTr("Couldn't rename thread: %1").arg(error)
            if (root.editor)
                root.editor.forceActiveFocus(Qt.OtherFocusReason)
        }
    }

    onThreadIdChanged: d.reset()
    onCanEditChanged: if (!canEdit) d.reset()

    QtObject {
        id: d
        property bool editing: false
        property bool submitted: false
        property string draft
        property string error

        function reset() {
            editing = false
            submitted = false
            draft = ""
            error = ""
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        StatusBaseText {
            Layout.fillWidth: true
            visible: !root.editing
            text: root.threadName
            textFormat: Text.PlainText
            font.bold: true
            elide: Text.ElideRight
        }

        Loader {
            id: inputLoader
            Layout.fillWidth: true
            active: root.editing
            visible: active
            onLoaded: {
                root.editor.text = d.draft
                root.editor.forceActiveFocus(Qt.OtherFocusReason)
                root.editor.selectAll()
            }
            sourceComponent: StatusTextArea {
                function submit() {
                    if (root.pending || d.submitted || inputMethodComposing)
                        return
                    if (text === "") {
                        d.error = qsTr("Thread name is required")
                        return
                    }
                    if (length > Constants.maxThreadNameLengthForRenaming) {
                        d.error = qsTr("Max %n character(s)", "", Constants.maxThreadNameLengthForRenaming)
                        return
                    }
                    d.error = ""
                    d.submitted = true
                    root.renameRequested(text.trim())
                }

                objectName: "threadNameInput"
                placeholderText: qsTr("Thread name")
                Accessible.name: placeholderText
                font.bold: true
                leftPadding: Theme.halfPadding
                rightPadding: Theme.halfPadding + submitButton.width
                topPadding: 3
                bottomPadding: 3
                readOnly: root.pending
                onTextEdited: {
                    d.draft = text
                    d.error = ""
                }
                Keys.onPressed: function(event) {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        event.accepted = true
                        d.reset()
                        break
                    case Qt.Key_Enter:
                    case Qt.Key_Return:
                        // e.g. Shift+Enter handled internally as newline
                        if (event.modifiers !== Qt.NoModifier)
                            return event.accepted = false
                        event.accepted = true
                        submit()
                        break
                    }
                }

                onActiveFocusChanged: {
                    if (!activeFocus)
                        d.reset()
                }

                StatusButton {
                    id: submitButton
                    objectName: "threadNameSubmitButton"
                    icon.name: "checkmark"
                    type: StatusRoundButton.Type.Primary
                    size: StatusBaseButton.Size.XSmall
                    height: parent.availableHeight
                    width: height
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    visible: parent.cursorVisible
                    interactive: !!parent.text
                    tooltip.orientation: StatusToolTip.Orientation.Bottom
                    tooltip.text: qsTr("Rename thread")
                    focusPolicy: Qt.NoFocus
                    onClicked: parent.submit()
                }
            }
        }

        StatusBaseText {
            Layout.fillWidth: true
            visible: !!root.parentChatName
            //: Thread header: %1 is the parent channel or chat name.
            text: qsTr("in %1").arg(root.parentChatName)
            textFormat: Text.PlainText
            font.pixelSize: Theme.additionalTextSize
            color: Theme.palette.baseColor1
            elide: Text.ElideRight
        }

        StatusBaseText {
            objectName: "threadNameError"
            Layout.fillWidth: true
            visible: root.pending || root.deletePending || !!d.error
            text: root.deletePending ? qsTr("Deleting...") : root.pending ? qsTr("Renaming...") : d.error
            textFormat: Text.PlainText
            font.pixelSize: Theme.additionalTextSize
            color: (root.pending || root.deletePending) ? Theme.palette.baseColor1 : Theme.palette.dangerColor1
            wrapMode: Text.Wrap
            Accessible.name: text
        }
    }

    StatusFlatButton {
        id: menuButton
        objectName: "threadHeaderMenuButton"
        visible: !!root.threadId
        enabled: !root.pending && !root.deletePending
        icon.name: "more"
        icon.color: Theme.palette.directColor1
        tooltip.text: qsTr("More")
        tooltip.orientation: StatusToolTip.Orientation.Bottom
        readonly property ThreadContextMenu menu: menuLoader.status === Loader.Ready
                                                  ? menuLoader.item as ThreadContextMenu : null
        onClicked: {
            menuLoader.active = true
            if (menuButton.menu)
                menuButton.menu.popup(-menuButton.menu.width + menuButton.width, menuButton.height + 4)
        }

        Loader {
            id: menuLoader
            active: false
            sourceComponent: ThreadContextMenu {
                objectName: "threadHeaderContextMenu"
                threadId: root.threadId
                isMobile: SQUtils.Utils.isMobile
                followed: root.followed
                onFollowRequested: root.followRequested()
                onUnfollowRequested: root.unfollowRequested()
                muted: root.muted
                onMuteRequested: interval => root.muteRequested(interval)
                onUnmuteRequested: root.unmuteRequested()
                pinned: false
                pinEnabled: false
                deleteEnabled: root.canEdit && !root.pending && !root.deletePending
                onDeleteRequested: {
                    d.reset()
                    d.error = ""
                    root.deleteRequested()
                }
                threadLinkToCopyShare: root.threadLinkToCopyShare
                editEnabled: root.canEdit && !root.pending && !root.deletePending
                onMarkAsReadRequested: root.markAsReadRequested()
                onEditNameRequested: root.editNameRequested()
            }
        }
    }
}
