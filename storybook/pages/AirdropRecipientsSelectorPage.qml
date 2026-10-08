import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Communities.controls

import Models
import Storybook


SplitView {
    orientation: Qt.Vertical

    Logs { id: logs }

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        AddressesModel {
            id: addresses
        }

        ListModel {
            id: members

            property int counter: 0

            function addMember() {
                const i = counter++
                const key = `pub_key_${i}`

                append({
                    alias: "",
                    colorId: "1",
                    displayName: `contact ${i}`,
                    ensName: "",
                    icon: "",
                    isContact: true,
                    localNickname: "",
                    onlineStatus: 1,
                    pubKey: key,
                    compressedPubKey: "compressed_" + key,
                    isVerified: true,
                    isUntrustworthy: false
                })
            }

            Component.onCompleted: {
                for (let i = 0; i < 4; i++)
                    addMember()
            }
        }

        AirdropRecipientsSelector {
            id: selector

            implicitWidth: 400
            anchors.centerIn: parent

            addressesModel: addresses
            loadingAddresses: timer.running
            membersModel: members
            showAddressesInputWhenEmpty:
                showAddressesInputWhenEmptyCheckBox.checked

            infiniteMaxNumberOfRecipients:
                infiniteMaxNumberOfRecipientsCheckBox.checked

            maxNumberOfRecipients: maxNumberOfRecipientsSpinBox.value

            onAddAddressesRequested: timer.start()
            onRemoveAddressRequested: addresses.remove(index)
            onRemoveMemberRequested: members.remove(index)

            Timer {
                id: timer

                interval: 1000

                onTriggered: {
                    addresses.addAddressesFromString(
                                selector.addressesInputText)
                    selector.clearAddressesInput()
                    selector.positionAddressesListAtEnd()
                }
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 100
        logsView.logText: logs.logText

        ColumnLayout {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right

            RowLayout {
                Button {
                    text: "Clear addresses list"
                    onClicked: addresses.clear()
                }

                Button {
                    text: "Clear members list"
                    onClicked: members.clear()
                }

                CheckBox {
                    id: showAddressesInputWhenEmptyCheckBox

                    text: "Show addresses input when empty"
                }

                CheckBox {
                    id: infiniteMaxNumberOfRecipientsCheckBox

                    text: "Infinite number of expected recipients"
                }
            }

            RowLayout {
                Label {
                    text: "Expected number of recipients:"
                }

                SpinBox {
                    id: maxNumberOfRecipientsSpinBox

                    value: 2
                    from: 1
                    to: 100
                }
            }

            Button {
                text: "Add member"
                onClicked: {
                    members.addMember()
                    loader.item.positionMembersListAtEnd()
                }
            }

            MenuSeparator {}

            TextEdit {
                readOnly: true
                selectByMouse: true
                text: "valid address: 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc4"
            }
        }
    }
}

// category: Components

// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=22628-494998
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=22628-495258
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=22647-497754
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=28045-533663
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=28045-533912
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=22628-495493
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=22628-495928
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=22628-496145
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=22642-496092
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=22647-498080
