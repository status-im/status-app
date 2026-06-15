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

    /* Indicates whether dApps button is visible */
    property bool dAppsVisible: true

    /* Indicates whether dApps button is enabled */
    property bool dAppsEnabled: true

    /* dApps model */
    property var dAppsModel

    /* Ens name or pre-elided address of the account */
    property string ensOrElidedAddress

    /* Indicates whether tokens are being loaded */
    property bool tokensLoading

    /* Formatted time of last reload */
    property string lastReloadedTime

    /* All accounts mode - color and emoji is not displayed, special title is set */
    property bool allAccounts

    /* Account name */
    property string name

    /* Account emoji */
    property string emojiId

    /* Account color */
    property color color

    /* Indicates whether balance for the account is available */
    property bool balanceAvailable

    /* Formatted account balance */
    property string balance

    /* Indicates whether balance is being loaded */
    property bool balanceLoading

    /* Networks model */
    property var networksModel

    /* Array of currently selected chains (chain ids) */
    property alias networksSelection: networkFilter.selection

    /* Indicates whether networks notification badge is visible */
    property bool showNetworksNotificationIcon

    /* Indicates whether the manage networks notification badge is visible */
    property bool showManageNetworksNotificationIcon

    /* Emitted when networks selection is changed */
    signal toggleNetworkRequested(string chainId)

    /* Emitted when the dApps list is opened */
    signal dappListRequested

    /* Emitted when new dApp connection is requested */
    signal dappConnectRequested

    /* Emitted when disconnecting of given dApp is requested */
    signal dappDisconnectRequested(string dappUrl)

    /* Emitted when networks management is requested */
    signal manageNetworksRequested

    /* Emitted when networks are presented to the user (via opening combobox) */
    signal networksShown

    /* Emitted when balacne reloading is requeste explicitly by the user */
    signal reloadRequested

    /* Emitted when address is clicked */
    signal addressClicked

    QtObject {
        id: d

        // switch to compact layout for lower width
        readonly property bool compact: root.width < 600

        //throttle for 1 min
        readonly property int reloadThrottleTimeMs: 1000 * 60
    }

    RowLayout {
        id: titleRow

        spacing: Theme.padding

        Rectangle {
            visible: !root.allAccounts

            Layout.preferredHeight: Math.min(parent.height, parent.width)
            Layout.preferredWidth: Layout.preferredHeight

            color: root.color
            radius: width / 2

            StatusEmoji {
                anchors.fill: parent
                anchors.margins: 11

                emojiId: root.emojiId

                Binding on source { // fallback when we have no emoji
                    when: root.emojiId === ""
                    value: Assets.svg("filled-account")
                }
            }
        }

        ColumnLayout {
            spacing: 0

            StatusBaseText {
                objectName: "walletHeaderTitle"

                Layout.fillWidth: true

                elide: Text.ElideRight
                font.pixelSize: Theme.fontSize(19)
                lineHeightMode: Text.FixedHeight
                lineHeight: 26

                text: root.allAccounts ? qsTr("All accounts") : root.name
            }

            StatusTextWithLoadingState {

                visible: root.balanceAvailable
                font.pixelSize: Theme.fontSize(19)
                font.weight: Font.Medium

                customColor: Theme.palette.directColor1
                text: root.balanceLoading ? Constants.dummyText : root.balance

                loading: root.balanceLoading
                lineHeightMode: Text.FixedHeight
                lineHeight: 26
            }
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

            loading: root.tokensLoading
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
    }

    RowLayout {
        id: controlRow

        DappsComboBox {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            visible: root.dAppsVisible
            enabled: root.dAppsEnabled
            model: root.dAppsModel
            dappClickable: false
            onDappListRequested: root.dappListRequested()
            onDisconnectDapp: (dappUrl) => root.dappDisconnectRequested(dappUrl)
            onConnectDapp: root.dappConnectRequested()
        }

        StatusButton {
            objectName: "walletHeaderButton"

            visible: !root.allAccounts
            Layout.preferredHeight: 38
            Layout.alignment: Qt.AlignHCenter

            text: root.ensOrElidedAddress

            spacing: 8
            size: StatusBaseButton.Size.Small
            borderColor: Theme.palette.directColor7
            normalColor: StatusColors.transparent
            hoverColor: Theme.palette.baseColor2

            font.weight: Font.Normal
            textPosition: StatusBaseButton.TextPosition.Left
            textColor: Theme.palette.baseColor1

            icon.name: "invite-users"
            icon.height: 16
            icon.width: 16
            icon.color: hovered ? Theme.palette.directColor1
                                : Theme.palette.baseColor1

            onClicked: root.addressClicked()
        }

        Item {
            visible: d.compact
            Layout.fillWidth: true
        }

        NetworkFilter {
            id: networkFilter

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: 38
            Layout.fillWidth: true
            Layout.maximumWidth: implicitWidth

            showTitle: false
            showManageNetworksButton: true
            flatNetworks: root.networksModel
            showNewChainIcon: true
            showNotificationIcon: root.showNetworksNotificationIcon
            showManageNetworksNotificationIcon: root.showManageNetworksNotificationIcon

            onToggleNetwork: chainId => root.toggleNetworkRequested(chainId)
            onManageNetworksClicked: root.manageNetworksRequested()

            popup.onOpened: root.networksShown()
        }
    }

    contentItem: ColumnLayout {
        spacing: Theme.padding

        RowLayout {
            LayoutItemProxy {
                Layout.fillWidth: true

                target: titleRow
            }

            LayoutItemProxy {
                visible: !d.compact

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter

                target: controlRow
            }
        }

        LayoutItemProxy {
            visible: d.compact

            Layout.fillWidth: true

            target: controlRow
        }
    }
}
