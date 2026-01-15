import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook
import Models

import utils
import shared.status

import StatusQ.Core.Utils as SQUtils

SplitView {
    id: root

    orientation: Qt.Vertical

    function openGifTestPopup(params, cbOnGifSelected, cbOnClose)
    {
        const popupParams = {
            cbOnGifSelected: cbOnGifSelected,
            cbOnClose: cbOnClose,
            popupParent: params.popupParent,
            parentXPosition: params.popupParent.x + params.popupParent.width,
            parentYPosition: params.popupParent.y,
        }

        const gifPopupInst = gifPopupComponent.createObject(params.popupParent,
                                                            popupParams)
        gifPopupInst.open()
    }

    Logs { id: logs }

    QtObject {
        id: d

        property bool linkPreviewsEnabled: linkPreviewSwitch.checked && !askToEnableLinkPreviewSwitch.checked
        onLinkPreviewsEnabledChanged: {
            loadLinkPreviews(chatInput.unformattedText)
        }
        function loadLinkPreviews(text) {
            const words = text.split(/\s+/)
            const data = []

            words.forEach(word => {
                if (!Utils.isURL(word))
                    return

                const linkPreview = fakeLinksModel.getStandardLinkPreview()
                linkPreview.url = encodeURI(word)
                linkPreview.unfurled = Math.random() > 0.2
                linkPreview.immutable = !d.linkPreviewsEnabled
                linkPreview.empty = Math.random() > 0.7
                data.push(linkPreview)
            })

            fakeLinksModel.clear()
            fakeLinksModel.append(data)
        }
    }

    ListModel {
        id: paymentRequestModel
    }

    UsersModel {
        id: fakeUsersModel
    }

    LinkPreviewModel {
        id: fakeLinksModel

        Component.onCompleted: clear()
    }

    Item {
        SplitView.fillHeight: true
        SplitView.fillWidth: true

        ColumnLayout {
            Label {
                text: "unformatted: " + chatInput.unformattedText
            }
            Label {
                text: "formatted: " + chatInput.textInput.text
            }
        }

        StatusChatInput {
            id: chatInput

            anchors.centerIn: parent

            width: 700

            property string unformattedText:
                chatInput.textInput.getText(0, chatInput.textInput.length)

            SQUtils.ModelChangeTracker {
                id: urlsModelChangeTracker

                model: fakeLinksModel
            }

            onUnformattedTextChanged: {
                Qt.callLater(() => {
                    d.loadLinkPreviews(unformattedText)

                    if(chatInput.unformattedText !== chatInput.textInput.getText(0, chatInput.textInput.length))
                        chatInput.unformattedText = chatInput.textInput.getText(0, chatInput.textInput.length)
                })
            }

            enabled: enabledCheckBox.checked
            linkPreviewModel: fakeLinksModel
            paymentRequestModel: paymentRequestModel
            urlsList: {
                urlsModelChangeTracker.revision
                return SQUtils.ModelUtils.modelToFlatArray(fakeLinksModel, "url")
            }
            askToEnableLinkPreview: askToEnableLinkPreviewSwitch.checked
            onAskToEnableLinkPreviewChanged: {
                if(askToEnableLinkPreview) {
                    fakeLinksModel.clear()
                    d.loadLinkPreviews(unformattedText)
                }
            }
            usersModel: fakeUsersModel

            paymentRequestFeatureEnabled: true
            areTestNetworksEnabled: testnetEnabledCheckBox.checked

            onSendMessage: {
                console.log()

                logs.logEvent("StatusChatInput::sendMessage", ["MessageWithPk"], [chatInput.getTextWithPublicKeys()])
                logs.logEvent("StatusChatInput::sendMessage", ["PlainText"], [SQUtils.StringUtils.plainText(chatInput.getTextWithPublicKeys())])
                logs.logEvent("StatusChatInput::sendMessage", ["RawText"], [chatInput.textInput.text])
                imageNb.currentIndex = 0 // images cleared
                linksNb.currentIndex = 0 // links cleared
            }
            onEnableLinkPreviewForThisMessage: {
                linkPreviewSwitch.checked = true
                askToEnableLinkPreviewSwitch.checked = false
            }
            onEnableLinkPreview: {
                linkPreviewSwitch.checked = true
                askToEnableLinkPreviewSwitch.checked = false
            }
            onDisableLinkPreview: {
                linkPreviewSwitch.checked = false
                askToEnableLinkPreviewSwitch.checked = false
            }
            onDismissLinkPreviewSettings: {
                askToEnableLinkPreviewSwitch.checked = false
                linkPreviewSwitch.checked = false
            }
            onDismissLinkPreview: (index) => {
                fakeLinksModel.setProperty(index, "unfurled", false)
                fakeLinksModel.setProperty(index, "immutable", true)
            }
            onRemovePaymentRequestPreview: (index) => {
                paymentRequestModel.remove(index)
            }
            onOpenGifPopupRequest: (params, cbOnGifSelected, cbOnClose) => {
                                       logs.logEvent("StatusChatInput:openGifPopupRequest --> Open GIF Popup Request!")
                                       root.openGifTestPopup(params, cbOnGifSelected, cbOnClose)
                                   }
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 300
        SplitView.preferredHeight: 300

        logsView.logText: logs.logText

        ColumnLayout {
            anchors.fill: parent

            RowLayout {
                CheckBox {
                    id: enabledCheckBox
                    text: "enabled"
                    checked: true
                }

                CheckBox {
                    id: testnetEnabledCheckBox
                    text: "testnet enabled"
                    checked: false
                }
            }

            RowLayout {
                Switch {
                    id: linkPreviewSwitch

                    text: "Link preview enabled"
                }

                Switch {
                    id: askToEnableLinkPreviewSwitch
                    text: "Ask to enable link preview"
                    checked: true
                }
            }

            RowLayout {
                Label {
                    text: "Links"
                }

                ComboBox {
                    id: linksNb

                    editable: true
                    model: 20

                    validator: IntValidator {
                        bottom: 0
                        top: 20
                    }

                    onCurrentIndexChanged: {
                        let urls = ""
                        for (let i = 0; i < linksNb.currentIndex ; i++) {
                            urls += "https://www.youtube.com/watch?v=9bZkp7q19f0" + Math.floor(Math.random() * 100) + " "
                        }

                        chatInput.textInput.text = urls
                    }
                }

                ToolSeparator {}

                Label {
                    text: "Images"
                }
                ComboBox {
                    id: imageNb

                    editable: true
                    model: 20
                    validator: IntValidator {bottom: 0; top: 20;}
                    focus: true
                    onCurrentIndexChanged: {
                        const urls = []
                        for (let i = 0; i < imageNb.currentIndex ; i++) {
                            urls.push("https://picsum.photos/200/300?random=" + i)
                        }
                        chatInput.fileUrlsAndSources = urls
                    }
                }
            }

            MenuSeparator {
                Layout.fillWidth: true
            }

            RowLayout {
                Label { text: "Amount:" }
                TextField {
                    id: paymentRequestAmount

                    text: "1"
                }

                Label { text: "Asset:" }
                TextField {
                    id: paymentRequestAsset

                    text: "1"
                }
            }

            Button {
                text: "Add payment request"
                enabled: paymentRequestAmount.text !== "" && paymentRequestAsset.text !== ""
                onClicked: {
                    paymentRequestModel.append({
                        amount: paymentRequestAmount.text,
                        symbol: paymentRequestAsset.text
                    })
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }

    Component {
        id: gifPopupComponent

        Popup {
            id: testPopup

            required property var cbOnGifSelected
            required property var cbOnClose
            required property var popupParent
            required property var parentXPosition
            required property var parentYPosition

            x: parentXPosition - width - 8
            y: parentYPosition - height

            ColumnLayout {
                Button {
                    text: "Send GIF 1"
                    onClicked: {

                        cbOnGifSelected("GIF 1", "URL GIF 1")
                        testPopup.close()
                    }
                }
                Button {
                    text: "Send GIF 2"
                    onClicked: {

                        cbOnGifSelected("GIF 2", "URL GIF 2")
                        testPopup.close()
                    }
                }

            }
            onClosed: {
                cbOnClose()
                destroy()
            }

        }
    }
}

// category: Components
// status: good
// https://www.figma.com/design/Mr3rqxxgKJ2zMQ06UAKiWL/Messenger----Desktop-Legacy?node-id=4360-175&m=dev
// https://www.figma.com/design/Mr3rqxxgKJ2zMQ06UAKiWL/Messenger----Desktop-Legacy?node-id=25492-31491&m=dev
