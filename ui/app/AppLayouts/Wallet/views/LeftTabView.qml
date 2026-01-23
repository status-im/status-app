import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import SortFilterProxyModel

import StatusQ.Core
import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Popups

import utils
import shared
import shared.panels
import shared.controls
import shared.popups
import shared.popups.keycard
import shared.popups.addaccount
import shared.stores

import AppLayouts.Wallet

import "../controls"
import "../popups"
import "../stores"

Rectangle {
    id: root
    objectName: "walletLeftTab"

    property NetworkConnectionStore networkConnectionStore
    property var selectAllAccounts: function(){}
    property var changeSelectedAccount: function(){}
    property var selectSavedAddresses: function(){}
    property var selectFollowingAddresses: function(){}
    property var emojiPopup: null

    property bool isKeycardEnabled: true

    color: Theme.palette.secondaryMenuBackground

    Component.onCompleted: {
        d.loaded = true
    }

    QtObject {
        id: d

        property bool loaded: false

        readonly property string removeAccountIdentifier: "wallet-section-remove-account"
    }

    Loader {
        id: addAccount
        active: false

        sourceComponent: AddAccountPopup {
            isKeycardEnabled: root.isKeycardEnabled
            store.emojiPopup: root.emojiPopup
            store.addAccountModule: walletSection.addAccountModule
        }

        onLoaded: {
            addAccount.item.open()
        }
    }

    Loader {
        id: walletAccountContextMenu
        active: false
        sourceComponent: AccountContextMenu {
            property var account: null
            address: {
                if (!account)
                    return ""
                return account.mixedcaseAddress
            }
            name: account ? account.name : ""
            walletType: account ? account.walletType : ""
            canDelete: account && !account.isWallet
            hideFromTotalBalance: account && account.hideFromTotalBalance

            onClosed: {
                walletAccountContextMenu.active = false
            }

            onAddNewAccountClicked: {
                RootStore.runAddAccountPopup()
            }

            onAddWatchOnlyAccountClicked: {
                RootStore.runAddWatchOnlyAccountPopup()
            }

            onEditAccountClicked: {
                if (!account)
                    return
                RootStore.runEditAccountPopup(account.address)
            }

            onDeleteAccountClicked: {
                if (!account)
                    return
                removeAccountConfirmation.accountType = account.walletType
                removeAccountConfirmation.accountName = account.name
                removeAccountConfirmation.accountAddress = account.address
                removeAccountConfirmation.accountDerivationPath = account.path
                removeAccountConfirmation.emoji = account.emoji
                removeAccountConfirmation.colorId = account.colorId
                removeAccountConfirmation.active = true
            }

            onHideFromTotalBalanceClicked: function (hideFromTotalBalance) {
                if (!account)
                    return
                RootStore.updateWatchAccountHiddenFromTotalBalance(account.address, hideFromTotalBalance)
            }
        }
    }

    Loader {
        id: removeAccountConfirmation
        active: false

        property string accountType
        property string accountKeyUid
        property string accountName
        property string accountAddress
        property string accountDerivationPath
        property string emoji
        property string colorId

        sourceComponent: RemoveAccountConfirmationPopup {
            accountType: removeAccountConfirmation.accountType
            accountName: removeAccountConfirmation.accountName
            accountAddress: removeAccountConfirmation.accountAddress
            accountDerivationPath: removeAccountConfirmation.accountDerivationPath
            emoji: removeAccountConfirmation.emoji
            color: Utils.getColorForId(Theme.palette, removeAccountConfirmation.colorId)

            function doDeletion(password) {
                close()
                RootStore.deleteAccount(removeAccountConfirmation.accountAddress, password)
            }

            onClosed: {
                removeAccountConfirmation.active = false
            }

            onRemoveAccount: {
                if (removeAccountConfirmation.accountType === Constants.watchWalletType) {
                    doDeletion("")
                    return
                }
                RootStore.authenticateLoggedInUser(d.removeAccountIdentifier)
            }

            Connections {
                target: RootStore
                enabled: removeAccountConfirmation.active

                function onLoggedInUserAuthenticated(requestedBy: string, password: string, pin: string, keyUid: string, keycardUid: string) {
                    if (d.removeAccountIdentifier !== requestedBy || password === "") {
                        return
                    }
                    doDeletion(password)
                }
            }
        }

        onLoaded: {
            removeAccountConfirmation.item.open()
        }
    }

    Connections {
        target: walletSection

        function onDisplayAddAccountPopup() {
            addAccount.active = true
        }
        function onDestroyAddAccountPopup() {
            addAccount.active = false
        }
    }

    StatusMouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton

        onClicked: {
            if (mouse.button === Qt.RightButton) {
                walletAccountContextMenu.active = true
                walletAccountContextMenu.item.popup(mouse.x, mouse.y)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: icon.height
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            Layout.topMargin: Theme.padding

            StatusMouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: mouse.accepted = true
            }

            StatusBaseText {
                id: walletTitleText
                text: qsTr("Wallet")
                font.weight: Font.Bold
                font.pixelSize: Theme.secondaryAdditionalTextSize
                color: Theme.palette.directColor1
                anchors.verticalCenter: parent.verticalCenter
            }

            StatusRoundButton {
                id: icon
                objectName: "addAccountButton"
                Accessible.name: SQUtils.Utils.formatAccessibleName(
                    qsTr("Add account"),
                    "addAccountButton"
                )
                icon.name: "add-circle"
                anchors.right: parent.right
                anchors.rightMargin: -Theme.smallPadding
                anchors.verticalCenter: parent.verticalCenter
                icon.width: 24
                icon.height: 24
                color: hovered || highlighted ? Theme.palette.primaryColor3
                                              : "transparent"
                onClicked: RootStore.runAddAccountPopup()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.minimumHeight: Theme.bigPadding
            color: root.color
            z: 2

            layer.enabled: !walletAccountsListView.atYBeginning
            layer.effect: DropShadow {
                verticalOffset: 10
                radius: 20
                samples: 41
                fast: true
                cached: true
                color: Theme.palette.dropShadow2
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true

            StatusListView {
                id: walletAccountsListView
                objectName: "walletAccountsListView"
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: parent.height - footer.height

                spacing: Theme.smallPadding
                currentIndex: -1
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: 0
                preferredHighlightEnd: height
                bottomMargin: Theme.padding

                readonly property Item firstItem: count > 0 ? itemAtIndex(0) : null
                readonly property bool footerOverlayed: d.loaded && contentHeight > availableHeight

                delegate: StatusListItem {
                    objectName: "walletAccountListItem"
                    readonly property bool itemLoaded: !model.assetsLoading // needed for e2e tests
                    width: ListView.view.width - Theme.padding * 2
                    highlighted: RootStore.selectedAddress.toLowerCase() === model.address.toLowerCase()
                    onHighlightedChanged: {
                        if (highlighted)
                            ListView.view.currentIndex = index
                    }
                    anchors.horizontalCenter: !!parent ? parent.horizontalCenter : undefined
                    title: model.name
                    subTitle: !model.hideFromTotalBalance ? LocaleUtils.currencyAmountToLocaleString(model.currencyBalance): ""
                    asset.emoji: !!model.emoji ? model.emoji: ""
                    asset.color: Utils.getColorForId(Theme.palette, model.colorId)
                    asset.name: !model.emoji ? "filled-account": ""
                    asset.width: 40
                    asset.height: 40
                    asset.letterSize: 14
                    asset.isLetterIdenticon: !!model.emoji ? true : false
                    asset.bgColor: Theme.palette.primaryColor3
                    statusListItemTitle.font.weight: Font.Medium
                    color: sensor.containsMouse || highlighted ? Theme.palette.baseColor3 : "transparent"
                    statusListItemSubTitle.loading: !!model.assetsLoading
                    errorMode: networkConnectionStore.accountBalanceNotAvailable
                    errorIcon.tooltip.maxWidth: 300
                    errorIcon.tooltip.text: networkConnectionStore.accountBalanceNotAvailableText
                    onClicked: function(itemId, mouse) {
                        if (mouse.button === Qt.RightButton) {
                            walletAccountContextMenu.active = true
                            walletAccountContextMenu.item.account = model
                            walletAccountContextMenu.item.popup(this, mouse.x, mouse.y)
                            return
                        }
                        changeSelectedAccount(model.address)
                    }
                    components: [
                        StatusIcon {
                            width: !!icon ? 15: 0
                            height: !!icon ? 15: 0
                            color: Theme.palette.directColor1
                            icon: model.walletType === Constants.watchWalletType ? "show" : ""
                        },
                        StatusIcon {
                            width: !!icon ? 15: 0
                            height: !!icon ? 15: 0
                            color: Theme.palette.directColor1
                            icon: model.keycardAccount ? "keycard" : ""
                        }
                    ]
                }

                header: Button {
                    id: header
                    verticalPadding: Theme.padding
                    horizontalPadding: Theme.padding
                    highlighted: RootStore.showAllAccounts
                    objectName: "allAccountsBtn"

                    leftInset: Theme.padding
                    bottomInset: Theme.padding
                    leftPadding: Theme.xlPadding
                    bottomPadding: Theme.bigPadding

                    background: Rectangle {
                        radius: Theme.radius
                        color: header.highlighted || header.hovered ? Theme.palette.backgroundHover : root.color
                        implicitWidth: parent.ListView.view.width - Theme.padding * 2
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                    onClicked: root.selectAllAccounts()

                    contentItem: ColumnLayout {
                        spacing: 0
                        StatusBaseText {
                            id: allAccounts
                            color: Theme.palette.baseColor1
                            text: qsTr("All accounts")
                            font.weight: Font.Medium
                            font.pixelSize: Theme.primaryTextFontSize
                            lineHeightMode: Text.FixedHeight
                            lineHeight: 22
                        }
                        RowLayout {
                            spacing: 4
                            StatusTextWithLoadingState {
                                id: walletAmountValue
                                objectName: "walletLeftListAmountValue"
                                customColor: Theme.palette.textColor
                                text: LocaleUtils.currencyAmountToLocaleString(RootStore.totalCurrencyBalance, {noSymbol: true})
                                font.pixelSize: Theme.fontSize(22)
                                loading: RootStore.balanceLoading
                                lineHeightMode: Text.FixedHeight
                                lineHeight: 36
                                verticalAlignment: Text.AlignVCenter
                            }
                            StatusTextWithLoadingState {
                                customColor: Theme.palette.textColor
                                text: RootStore.totalCurrencyBalance.symbol
                                font.pixelSize: Theme.additionalTextSize
                                loading: RootStore.balanceLoading
                                font.weight: Font.Medium
                                lineHeightMode: Text.FixedHeight
                                lineHeight: 22
                                verticalAlignment: Text.AlignBottom
                            }
                            visible: !networkConnectionStore.accountBalanceNotAvailable
                        }
                        StatusFlatRoundButton {
                            id: errorIcon
                            Layout.preferredWidth: 14
                            Layout.preferredHeight: 14
                            icon.width: 14
                            icon.height: 14
                            icon.name: "tiny/warning"
                            icon.color: Theme.palette.dangerColor1
                            tooltip.text: networkConnectionStore.accountBalanceNotAvailableText
                            tooltip.maxWidth: 200
                            visible: networkConnectionStore.accountBalanceNotAvailable
                        }
                    }
                }

                model: SortFilterProxyModel {
                    sourceModel: RootStore.accounts
                    sorters: RoleSorter { roleName: "position"; sortOrder: Qt.AscendingOrder }
                }
            }

            Control {
                id: footer

                anchors {
                    top: parent.top
                    // Bottom Margin is not applied to ListView if it's fully visible
                    topMargin: Math.min(walletAccountsListView.contentHeight, parent.height - height) + (walletAccountsListView.footerOverlayed ? 0 : walletAccountsListView.bottomMargin)
                    left: parent.left
                    right: parent.right
                }

                horizontalPadding: Theme.padding
                verticalPadding: Theme.padding

                background: Rectangle {
                    id: footerBackground
                    color: root.color
                    implicitWidth: root.width
                    implicitHeight: (walletAccountsListView.firstItem?.height ?? Theme.xlPadding*2) + Theme.xlPadding

                    layer.enabled: walletAccountsListView.footerOverlayed && !walletAccountsListView.atYEnd
                    layer.effect: DropShadow {
                        verticalOffset: -10
                        radius: 20
                        samples: 41
                        fast: true
                        cached: true
                        color: Theme.palette.dropShadow2
                    }

                    Separator {
                        anchors.top: parent.top
                        anchors.topMargin: -1
                        width: parent.width
                    }
                }

                contentItem: StatusFlatButton {
                    objectName: "savedAddressesBtn"
                    highlighted: RootStore.showSavedAddresses
                    hoverColor: Theme.palette.backgroundHover
                    asset.bgColor: Theme.palette.primaryColor3
                    text: qsTr("Saved addresses")
                    icon.name: "address"
                    icon.width: 40
                    icon.height: 40
                    icon.color: Theme.palette.primaryColor1
                    isRoundIcon: true
                    textColor: Theme.palette.directColor1
                    textFillWidth: true
                    spacing: walletAccountsListView.firstItem?.statusListItemTitleArea.anchors.leftMargin ?? Theme.padding
                    onClicked: root.selectSavedAddresses()
                }
            }

            Control {
                id: followingAddressesFooter

                anchors {
                    top: footer.bottom
                    left: parent.left
                    right: parent.right
                }

                horizontalPadding: Theme.padding
                verticalPadding: 0

                contentItem: StatusFlatButton {
                    objectName: "followingAddressesBtn"
                    highlighted: RootStore.showFollowingAddresses
                    hoverColor: Theme.palette.backgroundHover
                    asset.bgColor: Theme.palette.primaryColor3
                    text: qsTr("EFP onchain friends")
                    icon.name: "contact"
                    icon.width: 40
                    icon.height: 40
                    icon.color: Theme.palette.primaryColor1
                    isRoundIcon: true
                    textColor: Theme.palette.directColor1
                    textFillWidth: true
                    spacing: walletAccountsListView.firstItem?.statusListItemTitleArea.anchors.leftMargin ?? Theme.padding
                    onClicked: root.selectFollowingAddresses()
                }
            }
        }
    }
}
