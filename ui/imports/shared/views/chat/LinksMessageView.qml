import QtQuick

import utils

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Utils as SQUtils

import shared.controls
import shared.panels
import shared.status
import shared.stores

import shared.controls.delegates

Flow {
    id: root

    property UtilsStore utilsStore

    required property bool isOnline
    required property bool playAnimations

    required property var linkPreviewModel
    required property var gifLinks

    required property var paymentRequestModel

    required property bool gifUnfurlingEnabled
    required property bool canAskToUnfurlGifs

    required property bool areTestNetworksEnabled

    property var formatBalance: null

    property string senderName
    property string senderThumbnailImage
    property int senderColorId

    readonly property alias hoveredLink: linksRepeater.hoveredUrl
    property string highlightLink: ""

    signal imageClicked(var image, var mouse, string imageSource, string url)
    signal openContextMenu(var item, string url, string domain)
    signal setNeverAskAboutUnfurlingAgain(bool neverAskAgain)
    signal paymentRequestClicked(int index)

    function resetLocalAskAboutUnfurling() {
        d.localAskAboutUnfurling = true
    }

    spacing: 12

    //TODO: remove once GIF previews are unfurled sender side

    QtObject {
        id: d

        property bool localAskAboutUnfurling: true
        readonly property int maximumContentWidth: 300
        readonly property int contentWidth: Math.min(maximumContentWidth, root.width)
    }

    Loader {
        visible: active
        active: root.gifLinks && root.gifLinks.length > 0
                 && !root.gifUnfurlingEnabled
                 && d.localAskAboutUnfurling && root.canAskToUnfurlGifs
        sourceComponent: enableLinkComponent
    }

    Repeater {
        id: paymentRequestRepeater
        model: root.paymentRequestModel
        delegate: PaymentRequestCardDelegate {
            required property var model

            width: d.contentWidth

            objectName: "PaymentRequestDelegate_" + model.index
            areTestNetworksEnabled: root.areTestNetworksEnabled
            amount: {
                if (!root.formatBalance)
                    return model.amount
                return root.formatBalance(model.amount, model.tokenKey)
            }
            symbol: model.symbol
            address: model.receiver
            logoUri: model.logoUri
            senderName: root.senderName
            senderThumbnailImage: root.senderThumbnailImage
            senderColorId: root.senderColorId

            onClicked: {
                root.paymentRequestClicked(model.index)
            }
        }
    }

    Repeater {
        id: tempRepeater
        visible: root.canAskToUnfurlGifs
        model: root.gifUnfurlingEnabled ? gifLinks : []

        delegate: LinkPreviewGifDelegate {
            required property string modelData

            imageWidth: d.contentWidth

            link: modelData
            isOnline: root.isOnline
            playAnimation: root.playAnimations
            onClicked: mouse => root.imageClicked(imageAlias, mouse, link, link)
        }
    }

    Repeater {
        id: linksRepeater

        property string hoveredUrl: ""

        model: root.linkPreviewModel
        delegate: LinkPreviewCardDelegate {
            id: delegate

            width: d.contentWidth

            highlight: url === root.highlightLink
            onHoveredChanged: {
                linksRepeater.hoveredUrl = hovered ? url : ""
            }
            onClicked: (mouse) => {
                if(mouse.button === Qt.RightButton) {
                    const domain = previewType === Constants.LinkPreviewType.Standard ? linkData.domain : Constants.externalStatusLink
                    root.openContextMenu(delegate, url, domain)
                    return
                }

                if(previewType === Constants.LinkPreviewType.Standard) {
                    Global.requestOpenLink(url)
                    return
                }

                Global.activateDeepLink(url)
            }
        }
    }

    Component {
        id: enableLinkComponent

        Rectangle {
            id: enableLinkRoot
            implicitWidth: d.contentWidth
            implicitHeight: childrenRect.height + Theme.smallPadding
            radius: 16
            border.width: 1
            border.color: Theme.palette.border
            color: Theme.palette.background

            StatusFlatRoundButton {
                anchors.top: parent.top
                anchors.topMargin: Theme.smallPadding
                anchors.right: parent.right
                anchors.rightMargin: Theme.smallPadding
                icon.width: 20
                icon.height: 20
                icon.name: "close-circle"
                onClicked: d.localAskAboutUnfurling = false
            }
            Image {
                id: unfurlingImage
                source: Assets.png("unfurling-image")
                width: 132
                height: 94
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Theme.smallPadding
            }
            StatusBaseText {
                id: enableText
                text: qsTr("Enable automatic GIF unfurling")
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                wrapMode: Text.WordWrap
                anchors.top: unfurlingImage.bottom
                anchors.topMargin: Theme.halfPadding
                color: Theme.palette.directColor1
            }
            StatusBaseText {
                id: infoText
                text: qsTr("Once enabled, links posted in the chat may share your metadata with their owners")
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                wrapMode: Text.WordWrap
                anchors.top: enableText.bottom
                font.pixelSize: Theme.additionalTextSize
                color: Theme.palette.baseColor1
            }
            Separator {
                id: sep1
                anchors.top: infoText.bottom
                anchors.topMargin: Theme.smallPadding
            }
            StatusFlatButton {
                id: enableBtn
                objectName: "LinksMessageView_enableBtn"
                text: qsTr("Enable in Settings")
                onClicked: {
                    Global.changeAppSectionBySectionType(Constants.appSection.profile, Constants.settingsSubsection.messaging);
                }
                width: parent.width
                anchors.top: sep1.bottom
                Component.onCompleted: {
                    background.radius = 0
                }
            }
            Separator {
                id: sep2
                anchors.top: enableBtn.bottom
                anchors.topMargin: 0
            }

            StatusFlatButton {
                id: dontAskBtn
                width: parent.width
                height: 44
                anchors.top: sep2.bottom
                text: qsTr("Don't ask me again")
                onClicked: root.setNeverAskAboutUnfurlingAgain(true)
                Component.onCompleted: {
                    background.radius = 0
                    background.bottomRightRadius = Theme.padding
                    background.bottomRightRadius = Theme.padding
                }
            }
        }
    }
}

