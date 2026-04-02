import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Components
import StatusQ.Controls

import AppLayouts.Profile.controls

import utils

Rectangle {
    id: root

    required property string userProfileKeyUid
    required property string userProfileColor

    required property string keyPairKeyUid
    required property bool keyPairMigratedToKeycard
    required property string keyPairName
    required property string keyPairIcon
    required property string keyPairImage
    required property bool keyPairCardLocked
    required property string keyPairLocation // corresponds to Utils.getKeypairLocation
    required property string keyPairLocationColor // corresponds to Utils.getKeypairLocationColor

    required property bool areTestNetworksEnabled

    required property var keyPairAccounts // [ { "path", "address", "publicKey?" } ] from card metadata JSON
    property bool isKnownKeyPair: false

    readonly property bool isProfileKeyPair: root.keyPairKeyUid !== ""
                                             && root.keyPairKeyUid === root.userProfileKeyUid

    color: Theme.palette.baseColor2
    radius: Theme.halfPadding
    implicitWidth: 448
    implicitHeight: columnLayout.implicitHeight

    ColumnLayout {
        id: columnLayout

        width: parent.width
        spacing: Theme.halfPadding

        StatusListItem {
            id: keypairInfo
            Layout.fillWidth: true
            Layout.preferredWidth: parent.width
            color: StatusColors.transparent
            title: root.keyPairName
            visible: !!root.keyPairName
            titleTextIcon: root.keyPairMigratedToKeycard? "keycard": ""
            subTitle: root.keyPairLocation
            statusListItemSubTitle.textFormat: Qt.RichText
            statusListItemSubTitle.color: root.keyPairLocationColor

            asset {
                width: !!root.keyPairIcon? Theme.bigPadding : 40
                height: !!root.keyPairIcon? Theme.bigPadding : 40
                name: root.keyPairImage? root.keyPairImage
                                       : root.keyPairIcon? root.keyPairIcon
                                                         : root.isProfileKeyPair? "contact"
                                                                                : ""
                isImage: !!root.keyPairImage
                color: root.isProfileKeyPair? Theme.palette.indirectColor2
                                            : Theme.palette.primaryColor1
                letterSize: Math.max(4, asset.width / 2.4)
                charactersLen: 2
                isLetterIdenticon: !root.keyPairImage && !root.keyPairIcon && !root.isProfileKeyPair
                bgColor: root.isProfileKeyPair? root.userProfileColor
                                              : Theme.palette.primaryColor3
            }
        }

        StatusBaseText {
            Layout.preferredWidth: parent.width - 2 * Theme.padding
            Layout.leftMargin: Theme.padding
            Layout.alignment: Qt.AlignLeft
            Layout.topMargin: !keypairInfo.visible? Theme.xlPadding : 0
            visible: !root.isKnownKeyPair
            text: qsTr("Active Account(s)", "", Math.max(0, root.keyPairAccounts? root.keyPairAccounts.length : 0))
            color: Theme.palette.baseColor1
            wrapMode: Text.WordWrap
        }

        StatusListView {
            id: accountsList
            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight
            Layout.preferredWidth: parent.width
            Layout.bottomMargin: Theme.padding
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            clip: true
            spacing: Theme.halfPadding * 0.5
            model: root.keyPairAccounts

            delegate: Loader {
                id: accountsRowLoader

                width: accountsList.width
                height: item? item.implicitHeight : 0

                property var delegateModel: model
                property int delegateIndex: index

                asynchronous: false
                sourceComponent: root.isKnownKeyPair? walletKeyPairAccountListRowDelegate
                                                    : unknownKeyPairAccountListRowDelegate

                onLoaded: {
                    if (root.isKnownKeyPair) {
                        item.rowModel = delegateModel
                        item.rowIndex = delegateIndex
                        item.rowTotal = Qt.binding(() => ListView.view.count)
                        item.rowWidth = Qt.binding(() => accountsRowLoader.width)
                    } else {
                        item.rowModel = delegateModel
                        item.rowIndex = delegateIndex
                        item.rowWidth = Qt.binding(() => accountsRowLoader.width)
                    }
                }
            }
        }
    }

    Component {
        id: walletKeyPairAccountListRowDelegate
        WalletAccountDelegate {
            id: walletAccountRow

            property var rowModel
            property int rowIndex: -1
            property int rowTotal
            property real rowWidth

            readonly property var emptyAccount: ({
                                                     name: "",
                                                     address: "",
                                                     emoji: "",
                                                     colorId: ""
                                                 })

            implicitWidth: rowWidth
            account: rowModel && rowModel.account? rowModel.account : emptyAccount
            totalCount: rowTotal
            compIndex: rowIndex
            nextIconVisible: false
            sensor.hoverEnabled: false
        }
    }

    Component {
        id: unknownKeyPairAccountListRowDelegate
        Rectangle {
            id: unknownAccountRow

            property var rowModel
            property int rowIndex: -1
            property real rowWidth

            width: rowWidth
            readonly property real bodyHeight: Math.max(unknownRowLayout.implicitHeight + Theme.padding, Theme.xlPadding * 2)
            implicitHeight: bodyHeight
            height: bodyHeight
            color: Theme.palette.statusModal.backgroundColor
            radius: Theme.halfPadding

            readonly property var row: {
                const empty = {
                    address: "",
                    path: ""
                }
                if (rowIndex < 0)
                    return empty
                const m = rowModel
                if (m !== undefined && m !== null) {
                    if (m.account !== undefined && m.account !== null) {
                        return {
                            address: m.account.address ?? "",
                            path: m.account.path ?? ""
                        }
                    }
                    const md = m.modelData
                    if (md !== undefined && md !== null) {
                        if (md.account !== undefined && md.account !== null) {
                            return {
                                address: md.account.address ?? "",
                                path: md.account.path ?? ""
                            }
                        }
                        if (md.address !== undefined) {
                            return {
                                address: md.address ?? "",
                                path: md.path ?? ""
                            }
                        }
                    }
                    if (m.address !== undefined) {
                        return {
                            address: m.address ?? "",
                            path: m.path ?? ""
                        }
                    }
                }
                if (typeof rowIndex === "number" && root.keyPairAccounts !== undefined
                        && root.keyPairAccounts !== null) {
                    const r = root.keyPairAccounts[rowIndex]
                    if (r !== undefined && r !== null) {
                        if (r.account !== undefined && r.account !== null) {
                            return {
                                address: r.account.address ?? "",
                                path: r.account.path ?? ""
                            }
                        }
                        return {
                            address: r.address ?? "",
                            path: r.path ?? ""
                        }
                    }
                }
                return empty
            }

            RowLayout {
                id: unknownRowLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Theme.padding
                anchors.rightMargin: Theme.padding
                spacing: Theme.halfPadding

                Row {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0
                    padding: 0

                    StatusBaseText {
                        text: StatusQUtils.Utils.elideText(unknownAccountRow.row.address, 6, 4)
                        wrapMode: Text.WordWrap
                        color: Theme.palette.directColor1
                    }

                    StatusFlatRoundButton {
                        visible: unknownAccountRow.row.address !== ""
                        height: 20
                        width: 20
                        icon.name: "external"
                        icon.width: 16
                        icon.height: 16
                        onClicked: {
                            const addr = unknownAccountRow.row.address
                            if (!addr)
                                return
                            const link = Utils.getUrlForAddressOnNetwork(Constants.networkShortChainNames.mainnet,
                                                                         root.areTestNetworksEnabled,
                                                                         addr)
                            Global.requestOpenLink(link)
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.minimumWidth: Theme.halfPadding
                }

                StatusBaseText {
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    Layout.preferredWidth: unknownAccountRow.width * 0.42
                    Layout.maximumWidth: unknownAccountRow.width * 0.42
                    horizontalAlignment: Text.AlignRight
                    wrapMode: Text.WordWrap
                    text: unknownAccountRow.row.path
                    color: Theme.palette.baseColor1
                }
            }
        }
    }
}
