import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils
import shared.controls
import shared.popups.walletconnect
import shared.popups.walletconnect.controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Components.private as SQP

ComboBox {
    id: root

    signal dappListRequested()
    signal connectDapp()
    signal disconnectDapp(string dappUrl)
    signal dappClicked(string dappUrl)

    property bool showConnectButton: true
    property bool dappClickable: true
    property bool incognitoMode: false
    property var popupDirectParent: root
    property int backgroundRadius: Theme.radius

    implicitHeight: 38
    implicitWidth: 38

    background: SQP.StatusComboboxBackground {
        objectName: "dappsBackground"
        active: root.down || root.hovered
        color: {
            if (!root.enabled)
                return Theme.palette.baseColor2

            if (!root.hovered)
                return StatusColors.transparent

            return root.incognitoMode
                    ? Theme.palette.privacyColors.secondary
                    : Theme.palette.directColor8;
        }
        border.width: 0
        radius: root.backgroundRadius
    }

    indicator: null

    contentItem: Item {
        objectName: "dappsContentItem"
        StatusBadge {
            objectName: "dappBadge"
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 5
            width: 6
            height: 6
            visible: root.delegateModel && root.delegateModel.count > 0
        }

        StatusIcon {
            objectName: "dappIcon"
            anchors.centerIn: parent
            width: 24
            height: 24
            icon: "dapp"
            color: root.incognitoMode ?
                       Theme.palette.privacyColors.tertiary:
                       Theme.palette.primaryColor1
        }
    }

    delegate: DAppDelegate {
        width: ListView.view.width
        clickable: root.dappClickable

        onDisconnectDapp: (dappUrl) => {
            root.disconnectDapp(dappUrl)
        }
        
        onDappClicked: (dappUrl) => {
            root.dappClicked(dappUrl)
        }
    }

    popup: DAppsListPopup {
        objectName: "dappsListPopup"

        directParent: root.popupDirectParent
        relativeX: {
            const globalX = directParent.mapToGlobal(directParent.width / 2, 0).x
            if (globalX < root.Window.width / 2)
               return 0

            return directParent.width - width
        }
        relativeY: directParent.height + 4

        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        background: Rectangle {
            color: root.incognitoMode ?
                       Theme.palette.privacyColors.primary:
                       Theme.palette.statusMenu.backgroundColor
            radius: Theme.radius
        }

        delegateModel: root.delegateModel
        showConnectButton: root.showConnectButton

        onConnectDapp: {
            root.connectDapp()
            this.close()
        }

        onOpened: {
            root.dappListRequested()
        }
    }

    StatusToolTip {
        id: tooltip
        objectName: "dappTooltip"
        visible: root.hovered && !root.down
        text: qsTr("dApp connections")
        orientation: StatusToolTip.Orientation.Bottom
        y: root.height + 14
    }
}
