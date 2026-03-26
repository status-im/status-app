import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Layout
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import utils
import shared
import shared.status
import shared.panels
import shared.controls

import "stores"
import "views"

StatusSectionLayout {
    id: root

    property RootStore store: RootStore {}

    Connections {
        target: root.store.nodeModelInst
        function onLog(logContent) {
            if(logContent.indexOf("mailserver") > 0){
                let lines = mailserverLogTxt.text.split("\n");
                if (lines.length > 10){
                    lines.shift();
                }
                lines.push(logContent.trim())
                mailserverLogTxt.text = lines.join("\n")
                mailserverScrollView.contentItem.contentY = mailserverScrollView.contentItem.contentHeight - mailserverScrollView.height
            } else {
                let lines = logsTxt.text.split("\n");
                if (lines.length > 5){
                    lines.shift();
                }
                lines.push(logContent.trim())
                logsTxt.text = lines.join("\n")
                logsScrollView.contentItem.contentY = logsScrollView.contentItem.contentHeight - logsScrollView.height
            }
        }
    }

    centerPanel: ColumnLayout {
        id: rpcColumn
        spacing: 0
        anchors.fill: parent

        RateView {
            store: root.store
            Layout.fillWidth: true
        }
        
        Column {
            Layout.fillWidth: true
            spacing: 0
            
            Row {
                width: parent.width
                spacing: 10
                topPadding: Theme.padding
                
                StatusBaseText {
                    text: qsTr("Peers")
                    width: 250
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    width: 140
                    height: 44
                    Input {
                        id: peerNumberInput
                        text: root.store.nodeModelInst.peerSize
                        width: parent.width
                        readOnly: true
                        customHeight: 44
                        placeholderText: "0"
                        anchors.top: parent.top
                    }
                }

                StatusBaseText {
                    text: qsTr("Latest Block")
                    width: 273
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    width: 140
                    height: 44
                    Input {
                        id: latestBlockInput
                        text: root.store.nodeModelInst.lastMessage
                        width: parent.width
                        readOnly: true
                        customHeight: 44
                        placeholderText: "0"
                        anchors.top: parent.top
                    }
                }
            }
        }

        ColumnLayout {
            id: mailserverLogsContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 0
            spacing: Theme.halfPadding
            
            StatusBaseText {
                color: Theme.palette.primaryColor1
                text: "Mailserver Interactions:"
                Layout.rightMargin: Theme.padding
                Layout.leftMargin: Theme.padding
                Layout.fillWidth: true
                font.weight: Font.Medium
                font.pixelSize: Theme.fontSize(20)
            }
            
            StatusScrollView {
                id: mailserverScrollView
                Layout.rightMargin: Theme.padding
                Layout.leftMargin: Theme.padding
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                padding: 0
                
                StatusTextArea {
                    id: mailserverLogTxt
                    width: mailserverScrollView.availableWidth
                    text: ""
                    readOnly: true
                }
            }
        }

        ColumnLayout {
            id: logContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 0
            spacing: Theme.halfPadding
            
            StatusBaseText {
                id: logHeaderDesc
                color: Theme.palette.primaryColor1
                text: "Logs:"
                Layout.rightMargin: Theme.padding
                Layout.leftMargin: Theme.padding
                Layout.fillWidth: true
                font.weight: Font.Medium
                font.pixelSize: Theme.fontSize(20)
            }
            
            StatusScrollView {
                id: logsScrollView
                Layout.rightMargin: Theme.padding
                Layout.leftMargin: Theme.padding
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                padding: 0
                
                StatusTextArea {
                    id: logsTxt
                    width: logsScrollView.availableWidth
                    text: ""
                    readOnly: true
                }
            }
        }

        ColumnLayout {
            id: rpcContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 0
            spacing: Theme.halfPadding
            
            StatusBaseText {
                color: Theme.palette.primaryColor1
                text: qsTr("JSON-RPC:")
                Layout.rightMargin: Theme.padding
                Layout.leftMargin: Theme.padding
                Layout.fillWidth: true
                font.weight: Font.Medium
                font.pixelSize: Theme.fontSize(20)
            }

            RowLayout {
                id: rpcInputContainer
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                Layout.leftMargin: Theme.padding
                Layout.rightMargin: Theme.padding
                Layout.bottomMargin: 0

                Item {
                    id: element2
                    width: 200
                    height: 50
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
                            anchors.topMargin: 12
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
                            anchors.topMargin: 12
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
                Layout.leftMargin: Theme.padding
                Layout.rightMargin: Theme.padding
                Layout.fillWidth: true
                Layout.fillHeight: true
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
