import QtQuick

import StatusQ
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

/*!
   \qmltype StatusMessageHeaderServices
   \inherits MessageHeaderServices
   \inqmlmodule StatusQ.Components
   \brief Runtime services shared by the message headers of a view.

   Holds the one clock connection, the one tooltip (created on first use)
   with its anchor, and the definition of the resend control, which headers
   instantiate only while they show one. Create one per view.
*/
MessageHeaderServices {
    id: root

    tooltipAnchor: Item {
        objectName: "messageHeaderTooltipAnchor"
    }

    resendButton: Component {
        StatusButton {
            required property MessageHeaderItem header

            objectName: "messageHeaderResendButton"
            verticalPadding: 2
            horizontalPadding: 6
            size: StatusBaseButton.Size.Small
            type: StatusBaseButton.Type.Warning
            font.pixelSize: Theme.tertiaryTextFontSize
            text: qsTranslate("StatusMessageHeader", "Resend")
            onClicked: header.resendClicked()
        }
    }

    readonly property Connections clockConnection: Connections {
        target: StatusSharedUpdateTimer
        function onTriggered() { root.tick() }
    }

    readonly property Loader tooltipLoader: Loader {
        active: false
        sourceComponent: StatusToolTip {
            id: tip

            // QQuickToolTip applies its show delay only to a completed popup.
            property bool completed: false
            Component.onCompleted: tip.completed = true

            objectName: root.tooltipObjectName
            parent: root.tooltipAnchor
            text: root.tooltipText
            visible: tip.completed && root.tooltipVisible && !!tip.text

            Binding on maxWidth {
                when: root.tooltipMaxWidth >= 0
                value: root.tooltipMaxWidth
            }
        }
    }

    onTooltipChanged: {
        if (root.tooltipVisible)
            root.tooltipLoader.active = true
    }
}
