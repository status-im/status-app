import QtQuick
import QtQml.Models

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

import AppLayouts.Communities.stores

StatusDialog {
    id: root

    property CommunitiesStore store

    property bool importingSingleChannel

    title: importingSingleChannel ? qsTr("Import a channel from Discord into Status") :
                                    qsTr("Import a community from Discord into Status")

    horizontalPadding: 16
    verticalPadding: 20
    width: 640

    onClosed: destroy()

    Component.onCompleted: {
        const buttons = contents.rightButtons
        for (let i = 0; i < buttons.length; i++) {
            footer.rightButtons.append(buttons[i])
        }
    }

    footer: StatusDialogFooter {
        id: footer
        bottomPadding: Theme.padding + root.parent.SafeArea.margins.bottom
        rightButtons: ObjectModel {}
    }

    background: StatusDialogBackground {
        color: Theme.palette.baseColor4
    }

    DiscordImportProgressContents {
        id: contents
        anchors.fill: parent
        store: root.store
        importingSingleChannel: root.importingSingleChannel
        onClose: root.close()
    }
}
