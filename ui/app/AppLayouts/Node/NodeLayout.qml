import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Layout
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import utils
import shared
import shared.panels
import shared.controls

import "stores"
import "views"

StatusSectionLayout {
    id: root

    property RootStore store: RootStore {}

    centerPanel: StatusScrollView {
        id: scrollView
        anchors.fill: parent
        contentWidth: availableWidth
        leftPadding: Theme.xlPadding * 2
        rightPadding: Theme.xlPadding * 2
        topPadding: Theme.bigPadding
        bottomPadding: Theme.bigPadding

        ColumnLayout {
            id: rpcColumn
            width: scrollView.availableWidth
            spacing: 0

            RateView {
                store: root.store
            }

            RowLayout {
                id: peerContainer2
                Layout.fillWidth: true
                StatusBaseText {
                    id: peerDescription
                    color: Theme.palette.primaryColor1
                    text: "Peers"
                    Layout.fillWidth: true
                    font.weight: Font.Medium
                    font.pixelSize: Theme.fontSize(20)
                }
                StatusBaseText {
                    id: peerNumber
                    color: Theme.palette.primaryColor1
                    // Not Refactored Yet
                    text: root.store.nodeModelInst.peerSize
                    Layout.fillWidth: true
                    font.weight: Font.Medium
                    font.pixelSize: Theme.fontSize(20)
                }
            }

            ColumnLayout {
                id: mailserverLogsContainer
                Layout.fillWidth: true
                StatusBaseText {
                    color: Theme.palette.primaryColor1
                    text: "Mailserver Interactions:"
                    Layout.fillWidth: true
                    font.weight: Font.Medium
                    font.pixelSize: Theme.fontSize(20)
                }
                StatusTextArea {
                    id: mailserverLogTxt
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    text: ""
                    readOnly: true
                }
            }

            ColumnLayout {
                id: logContainer
                Layout.fillWidth: true
                StatusBaseText {
                    id: logHeaderDesc
                    color: Theme.palette.primaryColor1
                    text: "Logs:"
                    Layout.fillWidth: true
                    font.weight: Font.Medium
                    font.pixelSize: Theme.fontSize(20)
                }
                StatusTextArea {
                    id: logsTxt
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    text: ""
                    readOnly: true
                }
            }

            // Not Refactored Yet
            Connections {
                target: root.store.nodeModelInst
                function onLog(logContent) {
                    // TODO: this is ugly, but there's not even a design for this section
                    if(logContent.indexOf("mailserver") > 0){
                        let lines = mailserverLogTxt.text.split("\n");
                        if (lines.length > 10){
                            lines.shift();
                        }
                        lines.push(logContent.trim())
                        mailserverLogTxt.text = lines.join("\n")
                    } else {
                        let lines = logsTxt.text.split("\n");
                        if (lines.length > 5){
                            lines.shift();
                        }
                        lines.push(logContent.trim())
                        logsTxt.text = lines.join("\n")
                    }
                }
            }

            ColumnLayout {
                id: messageContainer
                Layout.fillWidth: true
                StatusBaseText {
                    id: testDescription
                    color: Theme.palette.primaryColor1
                    text: "latest block (auto updates):"
                    Layout.fillWidth: true
                    font.weight: Font.Medium
                    font.pixelSize: Theme.fontSize(20)
                }
                StatusBaseText {
                    id: test
                    color: Theme.palette.primaryColor1
                    // Not Refactored Yet
                    text: root.store.nodeModelInst.lastMessage
                    Layout.fillWidth: true
                    font.weight: Font.Medium
                    font.pixelSize: Theme.fontSize(20)
                }
            }

            RowLayout {
                id: rpcInputContainer
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                Layout.bottomMargin: 0

                Item {
                    id: element2
                    height: 70
                    Layout.fillWidth: true

                    Rectangle {
                        id: rectangle
                        color: "#00000000"
                        border.color: Theme.palette.border
                        anchors.fill: parent

                        Button {
                            id: rpcSendBtn
                            x: 100
                            width: 30
                            height: 30
                            text: "\u2191"
                            font.bold: true
                            font.pointSize: 12
                            anchors.top: parent.top
                            anchors.topMargin: 20
                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            onClicked: {
                                root.store.onSend(txtData.text)
                                txtData.text = ""
                            }
                            enabled: txtData.text !== ""
                            background: Rectangle {
                                color: parent.enabled ? Theme.palette.primaryColor1 : Theme.palette.baseColor1
                                radius: 50
                            }
                        }

                        StatusTextField {
                            id: txtData
                            text: ""
                            leftPadding: 0
                            padding: 0
                            font.pixelSize: Theme.secondaryTextFontSize
                            placeholderText: qsTr("Type json-rpc message... e.g {\"method\": \"eth_accounts\"}")
                            anchors.right: rpcSendBtn.left
                            anchors.rightMargin: 16
                            anchors.top: parent.top
                            anchors.topMargin: 24
                            anchors.left: parent.left
                            anchors.leftMargin: 24
                            onAccepted: {
                                root.store.onSend(txtData.text)
                                txtData.text = ""
                            }
                            background: Rectangle {
                                color: "#00000000"
                            }
                        }
                    }
                }
            }

            StatusScrollView {
                id: resultScrollView
                Layout.fillWidth: true
                Layout.preferredHeight: 300
                contentWidth: availableWidth
                padding: 0

                StatusTextArea {
                    id: callResult
                    width: resultScrollView.availableWidth
                    text: root.store.nodeModelInst.callResult
                    readOnly: true
                }
            }
        }
    }
}
