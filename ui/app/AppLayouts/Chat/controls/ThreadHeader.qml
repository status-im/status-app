pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import "../popups"

RowLayout {
    id: root

    required property string threadId
    required property string threadName
    required property string parentChatName
    required property bool canEdit
    required property bool pending

    readonly property bool editing: d.editing
    readonly property StatusTextField editor: inputLoader.status === Loader.Ready
                                             ? inputLoader.item as StatusTextField : null

    signal renameRequested(string name)

    function beginEditing() {
        if (!root.canEdit || root.pending)
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
            sourceComponent: StatusTextField {
                objectName: "threadNameInput"
                placeholderText: qsTr("Thread name")
                Accessible.name: qsTr("Thread name")
                font.bold: true
                leftPadding: Theme.halfPadding
                rightPadding: Theme.halfPadding
                topPadding: 0
                bottomPadding: 0
                implicitHeight: 28
                readOnly: root.pending
                onTextEdited: {
                    d.draft = text
                    d.error = ""
                }
                onAccepted: {
                    if (root.pending || d.submitted || inputMethodComposing)
                        return
                    d.error = ""
                    d.submitted = true
                    root.renameRequested(text)
                }
                Keys.onEscapePressed: event => {
                    d.reset()
                    event.accepted = true
                }
            }
        }

        StatusBaseText {
            Layout.fillWidth: true
            visible: !!root.parentChatName
            text: qsTr("in %1").arg(root.parentChatName)
            textFormat: Text.PlainText
            font.pixelSize: Theme.additionalTextSize
            color: Theme.palette.baseColor1
            elide: Text.ElideRight
        }

        StatusBaseText {
            objectName: "threadNameError"
            Layout.fillWidth: true
            visible: root.pending || !!d.error
            text: root.pending ? qsTr("Renaming...") : d.error
            textFormat: Text.PlainText
            font.pixelSize: Theme.additionalTextSize
            color: root.pending ? Theme.palette.baseColor1 : Theme.palette.dangerColor1
            wrapMode: Text.Wrap
            Accessible.name: text
        }
    }

    StatusFlatRoundButton {
        id: menuButton
        objectName: "threadHeaderMenuButton"
        visible: root.canEdit
        enabled: !root.pending
        icon.name: "more"
        type: StatusFlatRoundButton.Type.Secondary
        tooltip.text: qsTr("More")
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
                isMobile: SQUtils.Utils.isMobile
                followed: false
                muted: false
                pinned: false
                pinEnabled: false
                deleteEnabled: false
                threadLinkToCopyShare: ""
                editEnabled: root.canEdit && !root.pending
                isThread: true
                onEditNameRequested: Qt.callLater(root.beginEditing)
            }
        }
    }
}
