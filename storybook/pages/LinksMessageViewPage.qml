import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Models

import shared.views.chat
import shared.stores

SplitView {

    LinkPreviewModel {
        id: mockedLinkPreviewModel
    }

    PaymentRequestModel {
        id: mockedPaymentRequestModel
    }

    Pane {
        id: messageViewWrapper
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        LinksMessageView {
            id: linksMessageView
            
            anchors.fill: parent

            isOnline: true
            playAnimations: true
            linkPreviewModel: mockedLinkPreviewModel
            gifLinks: [ "https://media.tenor.com/qN_ytiwLh24AAAAC/cold.gif" ]
            paymentRequestModel: mockedPaymentRequestModel
            areTestNetworksEnabled: false

            senderName: "Alice"

            gifUnfurlingEnabled: d.gifUnfurlingEnabled
            onSetGifUnfurlingEnabled: d.gifUnfurlingEnabled = true
            canAskToUnfurlGifs: true
            onImageClicked: {
                console.log("image clicked")
            }
        }
    }

    QtObject {
        id: d
        property bool gifUnfurlingEnabled
    }

    Pane {
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 300
        
        ColumnLayout {
            spacing: 25
            ColumnLayout {
                Label {
                    text: qsTr("GIF unfuring settings")
                }
                CheckBox {
                    text: qsTr("Enabled")
                    checked: d.gifUnfurlingEnabled
                    onToggled: d.gifUnfurlingEnabled = !d.gifUnfurlingEnabled
                }
                CheckBox {
                    text: qsTr("Can ask about GIF unfurling")
                    checked: linksMessageView.canAskToUnfurlGifs
                    onClicked: linksMessageView.canAskToUnfurlGifs = !linksMessageView.canAskToUnfurlGifs
                }
                Button {
                    text: qsTr("Reset local `askAboutUnfurling` setting")
                    onClicked: linksMessageView.resetLocalAskAboutUnfurling()
                }
                CheckBox {
                    text: qsTr("Play animations")
                    checked: linksMessageView.playAnimations
                    onToggled: linksMessageView.playAnimations = !linksMessageView.playAnimations
                }
                CheckBox {
                    text: qsTr("Is online")
                    checked: linksMessageView.isOnline
                    onToggled: linksMessageView.isOnline = !linksMessageView.isOnline
                }
                CheckBox {
                    text: qsTr("Testnet enabled")
                    checked: linksMessageView.areTestNetworksEnabled
                    onToggled: linksMessageView.areTestNetworksEnabled = !linksMessageView.areTestNetworksEnabled
                }
            }
        }
    }
}
