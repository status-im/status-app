import AppLayouts.Wallet.controls
import AppLayouts.Wallet.views

import QtQuick
import QtQuick.Layouts

import StatusQ
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils

import shared.panels as SharedPanels

import utils

import QtModelsToolkit

Rectangle {
    id: root

    /**
        Expected roles (for both models):

        address     [string] - unique wallet address
        name        [string] (optional)
        color       [string] (optional)
        colorId     [string] (optional)
        emoji       [string] (optional)
        ens         [string] (optional)
    */
    required property var recipientsModel
    required property var recipientsFilterModel

    /** Search pattern in recipient view input **/
    readonly property string searchPattern: recipientInputLoader.searchPattern

    /** Currently selected recipient tab  **/
    readonly property alias selectedRecipientType: d.selectedRecipientType
    /** Selected recipient address. It is input and output property **/
    property alias selectedRecipientAddress: recipientInputLoader.selectedRecipientAddress

    /** Maximum number of tab elements from all tabs in tab bar **/
    property int highestTabElementCount: recipientsModel.ModelCount.count

    /** Can selector be interacted **/
    property bool interactive: true

    /** Visual height of the component. It might differ from actual height.
        The purpose is to be able to show non-interactive list with constant height for all tabs.
        This will not affect Flickable parents. **/
    readonly property int visualHeight: {
        // Adjust to filtered results height
        if (d.searchInProgress || !!selectedRecipientAddress)
            return implicitHeight
        const walletViewHeight = Math.max(walletView.contentHeight, emptyListText.height)
        const count = Math.max(3, highestTabElementCount)
        return implicitHeight + (count * walletView.delegateHeight - walletViewHeight)
    }

    /** Request ens address to be resolved **/
    signal resolveENS(string ensName, string uuid)

    function setText(text) {
        recipientInputLoader.setText(text)
    }

    function ensNameResolved(resolvedPubKey, resolvedAddress, uuid) {
        recipientInputLoader.ensNameResolved(resolvedPubKey, resolvedAddress, uuid)
    }

    implicitHeight: childrenRect.height + (!!selectedRecipientAddress ? 0 : Theme.halfPadding/2)
    color: Theme.palette.secondaryMenuBackground
    radius: 8

    onSearchPatternChanged: {
        if (d.highlightedIndex > -1)
            d.highlightedIndex = 0
    }

    QtObject {
        id: d

        readonly property bool allTabsAreEmpty: root.highestTabElementCount === 0
        readonly property bool searchInProgress: !!root.searchPattern && root.recipientsFilterModel.ModelCount.count > 0
        property int highlightedIndex: 0
        property int selectedRecipientType: Constants.RecipientAddressObjectType.RecentsAddress

        function handleKeyPressOnSearch(event) {
            if (!event || !d.searchInProgress || highlightedIndex === -1)
                return

            switch(event.key) {
                case Qt.Key_Return:
                case Qt.Key_Enter: {
                    const address = StatusQUtils.ModelUtils.get(root.recipientsFilterModel, d.highlightedIndex, "address")
                    recipientInputLoader.selectedRecipientAddress = address
                    event.accepted = true
                    return
                }
                case Qt.Key_Down: {
                    if (d.highlightedIndex < root.recipientsFilterModel.ModelCount.count - 1) {
                        d.highlightedIndex++
                    } else {
                        d.highlightedIndex = 0
                    }

                    event.accepted = true
                    return
                }
                case Qt.Key_Up: {
                    if (d.highlightedIndex > 0) {
                        d.highlightedIndex--
                    } else {
                        d.highlightedIndex = root.recipientsFilterModel.ModelCount.count - 1
                    }

                    event.accepted = true
                    return
                }
                default:
                    return
            }
        }
    }

    ColumnLayout {
        id: layout

        width: parent.width
        spacing: 0

        RecipientView {
            id: recipientInputLoader

            Layout.alignment: Qt.AlignTop
            Layout.fillWidth: true
            Layout.topMargin: Theme.smallPadding / 2

            interactive: root.interactive

            model: root.recipientsFilterModel

            onResolveENS: root.resolveENS(ensName, uuid)
            onKeyPressed: (event) => d.handleKeyPressOnSearch(event)
        }

        Rectangle {
            Layout.preferredHeight: 1
            Layout.fillWidth: true
            color: Theme.palette.baseColor2
            visible: !root.selectedRecipientAddress
        }

        StatusTabBar {
            id: recipientTypeTabBar

            objectName: "recipientTypeTabBar"

            Layout.alignment: Qt.AlignTop
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            Layout.topMargin: 12

            StatusTabButton {
                leftPadding: Theme.padding
                width: implicitWidth
                objectName: "recentAddressesTab"
                text: qsTr("Recent")
                onClicked: d.selectedRecipientType = Constants.RecipientAddressObjectType.RecentsAddress
            }
            StatusTabButton {
                width: implicitWidth
                objectName: "savedAddressesTab"
                text: qsTr("Saved")
                onClicked: d.selectedRecipientType = Constants.RecipientAddressObjectType.SavedAddress
            }
            StatusTabButton {
                width: implicitWidth
                objectName: "myAccountsTab"
                text: qsTr("My Accounts")
                onClicked: d.selectedRecipientType = Constants.RecipientAddressObjectType.Account
            }

            visible: !root.selectedRecipientAddress && !d.searchInProgress
        }

        Rectangle {
            Layout.preferredHeight: 1
            Layout.fillWidth: true
            color: Theme.palette.baseColor2
            visible: recipientTypeTabBar.visible
        }

        StatusBaseText {
            id: emptyListText
            Layout.alignment: Qt.AlignTop | Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.rightMargin: Theme.padding
            Layout.leftMargin: Theme.padding
            Layout.preferredHeight: walletView.delegateHeight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: Theme.palette.baseColor1
            text: {
                switch(root.selectedRecipientType) {
                    case Constants.RecipientAddressObjectType.RecentsAddress:
                        return qsTr("Recently used addresses will appear here")
                    case Constants.RecipientAddressObjectType.SavedAddress:
                        return qsTr("Your saved addresses will appear here")
                    case Constants.RecipientAddressObjectType.Account:
                        return qsTr("Add another account to send tokens between them")
                    default:
                        return ""
                }
            }
            wrapMode: Text.WordWrap
            visible: !root.selectedRecipientAddress && !d.searchInProgress && root.recipientsModel.ModelCount.count === 0 && !!text
        }

        ListView {
            id: walletView
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: Theme.halfPadding / 2
            Layout.fillWidth: true
            Layout.leftMargin: Theme.halfPadding / 2
            Layout.rightMargin: Theme.halfPadding / 2
            Layout.preferredHeight: childrenRect.height
            spacing: 0
            bottomMargin: Theme.smallPadding
            interactive: false
            model: root.selectedRecipientAddress ? null : (d.searchInProgress ? root.recipientsFilterModel : root.recipientsModel)

            readonly property int delegateHeight: 64

            delegate: RecipientViewDelegate {
                required property var model

                width: walletView.width
                height: walletView.delegateHeight

                name: model.name ?? ""
                address: model.address
                emoji: model.emoji ?? ""
                walletColor: model.color ?? ""
                walletColorId: model.colorId ?? ""
                ens: model.ens ?? ""

                highlighted: d.searchInProgress && model.index === d.highlightedIndex
                sensor.onContainsMouseChanged: d.highlightedIndex = sensor.containsMouse ? -1 : 0

                onClicked: recipientInputLoader.selectedRecipientAddress = address
            }
        }
    }
}
