import QtQuick

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

StatusInput {
    id: root

    // TODO: Use https://github.com/status-im/status-app/issues/6136

    enum Mode {
        WriteMode,
        ReadMode
    }

    required property int mode
    property bool readOnly: false

    input.edit.readOnly: root.readOnly
    input.font: Fonts.monoFont.family
    input.placeholderFont: root.input.font

    input.rightComponent: {
        switch (root.mode) {
        case StatusSyncCodeInput.Mode.WriteMode:
            return root.valid ? validCodeIconComponent : pasteButtonComponent
        case StatusSyncCodeInput.Mode.ReadMode:
            return copyButtonComponent
        }
    }
    rightPadding: 12

    Component {
        id: copyButtonComponent

        StatusButton {
            objectName: "syncCodeCopyButton"
            size: StatusBaseButton.Size.Tiny
            text: qsTr("Copy")
            onClicked: ClipboardUtils.setText(root.text)
        }
    }

    Component {
        id: pasteButtonComponent

        StatusPasteButton {
            objectName: "syncCodePasteButton"
            enabled: !root.readOnly
            onPasted: (text) => {
                if (text.length > 0)
                    root.input.text = text
            }
        }
    }

    Component {
        id: validCodeIconComponent

        StatusIcon {
            icon: "tiny/checkmark"
            color: Theme.palette.successColor1
        }
    }
}
