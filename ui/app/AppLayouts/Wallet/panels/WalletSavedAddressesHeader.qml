import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

import StatusQ
import StatusQ.Core
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import AppLayouts.Wallet.controls

import utils

Control {
    id: root

    /* Formatted time of last reload */
    property string lastReloadedTime

    /* Indicates whether the content is being loaded */
    property bool loading

    /* Emitted when balacne reloading is requeste explicitly by the user */
    signal reloadRequested

    /* Emitted when new address button is clicked */
    signal addNewAddressClicked

    QtObject {
        id: d

        readonly property bool compact: root.width < 600 &&
                                        root.availableWidth - headerButton.width - reloadButton.width - titleRow.spacing * 2 < titleText.implicitWidth

        //throttle for 1 min
        readonly property int reloadThrottleTimeMs: 1000 * 60
    }

    StatusButton {
        id: headerButton

        objectName: "walletHeaderButton"

        Layout.preferredHeight: 38

        text: qsTr("Add new address")
        size: StatusBaseButton.Size.Small
        normalColor: Theme.palette.primaryColor3
        hoverColor: Theme.palette.primaryColor2

        font.weight: Font.Medium
        textPosition: StatusBaseButton.TextPosition.Left
        textColor: Theme.palette.primaryColor1

        onClicked: root.addNewAddressClicked()
    }

    RowLayout {
        id: titleRow

        spacing: Theme.padding

        StatusBaseText {
            id: titleText

            objectName: "walletHeaderButton"

            Layout.fillWidth: true

            elide: Text.ElideRight

            font.pixelSize: Theme.fontSize(19)
            font.weight: Font.Medium

            text: qsTr("Saved addresses")
            lineHeightMode: Text.FixedHeight
            lineHeight: 26
        }

        StatusButton {
            id: reloadButton
            size: StatusBaseButton.Size.Tiny

            Layout.preferredHeight: 38
            Layout.preferredWidth: 38
            Layout.alignment: Qt.AlignVCenter

            borderColor: Theme.palette.directColor7
            borderWidth: 1

            normalColor: StatusColors.transparent
            hoverColor: Theme.palette.baseColor2

            icon.name: "refresh"
            icon.color: {
                if (!interactive) {
                    return Theme.palette.baseColor1;
                }
                if (hovered) {
                    return Theme.palette.directColor1;
                }

                return Theme.palette.baseColor1;
            }
            asset.mirror: true

            tooltip.text: qsTr("Last refreshed %1").arg(root.lastReloadedTime)
            tooltip.orientation: StatusToolTip.Orientation.Bottom
            tooltip.y: height + Theme.padding

            loading: root.loading
            interactive: !loading && !throttleTimer.running

            onClicked: root.reloadRequested()

            Timer {
                id: throttleTimer

                interval: d.reloadThrottleTimeMs

                // Start the timer immediately to disable manual reload initially,
                // as automatic refresh is performed upon entering the wallet.
                running: true
            }

            Connections {
                target: root

                function onLastReloadedTimeChanged() {
                    // Start the throttle timer whenever the tokens are reloaded,
                    // which can be triggered by either automatic or manual reload.
                    throttleTimer.restart()
                }
            }
        }

        LayoutItemProxy {
            visible: !d.compact
            target: headerButton
        }
    }

    contentItem: ColumnLayout {
        spacing: Theme.padding

        LayoutItemProxy {
            Layout.fillWidth: true

            target: titleRow
        }

        LayoutItemProxy {
            Layout.alignment: Qt.AlignRight
            Layout.fillWidth: true
            Layout.maximumWidth: implicitWidth
            visible: d.compact
            target: headerButton
        }
    }
}
