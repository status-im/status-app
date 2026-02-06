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
import shared.controls

Control {
    id: root

    /* Model of non-watch wallet accounts for the account selector */
    property var accountsModel

    /* The currently selected account address */
    readonly property string selectedAddress: accountSelector.currentAccountAddress

    /* Formatted time of last reload */
    property string lastReloadedTime

    /* Indicates whether the content is being loaded */
    property bool loading

    /* Emitted when balance reloading is requested explicitly by the user */
    signal reloadRequested

    /* Emitted when add via EFP button is clicked */
    signal addViaEFPClicked

    /* Emitted when the user selects a different account */
    signal accountChanged(string address)

    QtObject {
        id: d

        readonly property bool compact: root.availableWidth - headerButton.width - accountSelector.width - reloadButton.width - titleRow.spacing * 3 < titleText.implicitWidth

        //throttle for 1 min
        readonly property int reloadThrottleTimeMs: 1000 * 60
    }

    StatusButton {
        id: headerButton

        objectName: "walletHeaderButton"

        Layout.preferredHeight: 38

        text: qsTr("Find a friend")
        icon.name: "external-link"
        textPosition: StatusBaseButton.TextPosition.Left
        size: StatusBaseButton.Size.Small
        type: StatusBaseButton.Type.Primary

        onClicked: root.addViaEFPClicked()
    }

    AccountSelectorHeader {
        id: accountSelector
        model: root.accountsModel

        // Center the 32px content vertically within 38px height
        control.topPadding: 3
        control.bottomPadding: 3

        Layout.preferredHeight: 38
        Layout.preferredWidth: d.compact ? 48 : implicitWidth
        Layout.alignment: Qt.AlignVCenter

        onCurrentAccountAddressChanged: {
            if (currentAccountAddress)
                root.accountChanged(currentAccountAddress)
        }
    }

    RowLayout {
        id: titleRow

        spacing: Theme.padding

        StatusBaseText {
            id: titleText

            objectName: "walletHeaderTitle"

            Layout.fillWidth: true

            elide: Text.ElideRight

            font.pixelSize: Theme.fontSize(19)
            font.weight: Font.Medium

            text: qsTr("Onchain friends")
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

            normalColor: Theme.palette.transparent
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

        LayoutItemProxy {
            visible: !d.compact
            target: accountSelector
            Layout.rightMargin: 6 // compensate for rightInset: -6 bleed to align with content below
        }
    }

    contentItem: ColumnLayout {
        spacing: Theme.padding

        LayoutItemProxy {
            Layout.fillWidth: true

            target: titleRow
        }

        RowLayout {
            Layout.fillWidth: true
            visible: d.compact
            spacing: Theme.padding

            LayoutItemProxy {
                target: accountSelector
            }

            Item { Layout.fillWidth: true }

            LayoutItemProxy {
                target: headerButton
            }
        }
    }
}

