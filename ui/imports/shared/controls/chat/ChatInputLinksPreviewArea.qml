import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

import StatusQ.Core

import shared.status
import shared.controls.delegates

import utils

import SortFilterProxyModel

Control {
    id: root

    required property var imagePreviewArray
    /*
    Expected roles:
        string title
        string url
        bool unfurled
        bool immutable
        string hostname
        string description
        int linkType
        int thumbnailWidth
        int thumbnailHeight
        string thumbnailUrl
        string thumbnailDataUri
    */
    required property var linkPreviewModel
    required property bool showLinkPreviewSettings
    /*
    Expected roles:
        string symbol
        string amount
    */
    required property var paymentRequestModel

    property var formatBalance: null

    readonly property alias hoveredUrl: d.hoveredUrl
    readonly property bool hasContent: imagePreviewArray.length > 0 || showLinkPreviewSettings || linkPreviewRepeater.count > 0 || paymentRequestRepeater.count > 0

    signal imageRemoved(int index)
    signal imageClicked(var chatImage)
    signal linkReload(string link)
    signal linkClicked(string link)

    signal removePaymentRequestPreview(int index)

    signal enableLinkPreview()
    signal enableLinkPreviewForThisMessage()
    signal disableLinkPreview()
    signal dismissLinkPreviewSettings()
    signal dismissLinkPreview(int index)

    horizontalPadding: 12
    topPadding: 12

    contentItem: Item {
        id: opacityMaskWrapper
        
        anchors.fill: parent

        implicitWidth: flickable.implicitWidth
        implicitHeight: flickable.implicitHeight

        opacity: 0

        WheelHandler {
            target: flickable
            property: "contentX"
            acceptedDevices: PointerDevice.Mouse
            onActiveChanged: if(!active) flickable.returnToBounds()
        }

        Flickable {
            id: flickable
            
            anchors.fill: parent
            anchors.leftMargin: root.leftPadding
            anchors.rightMargin: root.rightPadding
            anchors.bottomMargin: root.bottomPadding
            anchors.topMargin: root.topPadding

            implicitHeight: contentHeight
            implicitWidth: contentWidth

            contentWidth: layout.width
            contentHeight: layout.height

            onFlickStarted: settingsContextMenu.close()

            RowLayout {
                id: layout
                spacing: 8
                StatusChatInputImageArea {
                    id: imageArea
                    Layout.preferredHeight: 64
                    spacing: layout.spacing
                    imageSource: imagePreviewArray
                    onImageClicked: (chatImage) => root.imageClicked(chatImage)
                    onImageRemoved: (index) => root.imageRemoved(index)
                    visible: !!imagePreviewArray && imagePreviewArray.length > 0
                }
                Repeater {
                    id: paymentRequestRepeater
                    model: root.paymentRequestModel
                    delegate: PaymentRequestMiniCardDelegate {
                        required property var model

                        amount: {
                            if (!root.formatBalance)
                                return model.amount
                            return root.formatBalance(model.amount, model.tokenKey)
                        }
                        symbol: model.symbol
                        logoUri: model.logoUri

                        onClose: {
                            root.removePaymentRequestPreview(model.index)
                        }
                    }
                }
                Repeater {
                    id: linkPreviewRepeater
                    model: d.filteredModel
                    delegate: LinkPreviewMiniCardDelegate {
                        required property int index

                        onClose: root.dismissLinkPreview(d.filteredModel.mapToSource(index))
                        onRetry: root.linkReload(url)
                        onClicked: root.linkClicked(url)
                        onRightClicked: settingsContextMenu.popup()
                        onContainsMouseChanged: {
                            if (containsMouse) {
                                d.hoveredUrl = url
                            } else if (d.hoveredUrl === url) {
                                d.hoveredUrl = ""
                            }
                        }
                        Component.onDestruction: {
                            if(d.hoveredUrl === url) {
                                d.hoveredUrl = ""
                            }
                        }
                    }
                }
                LinkPreviewSettingsCard {
                    id: settingsCard
                    visible: root.showLinkPreviewSettings
                    onDismiss: root.dismissLinkPreviewSettings()
                    onEnableLinkPreviewForThisMessage: root.enableLinkPreviewForThisMessage()
                    onEnableLinkPreview: root.enableLinkPreview()
                    onDisableLinkPreview: root.disableLinkPreview()
                }
            }
        }
    }
    
    Rectangle {
        id: horizontalClipMask
        anchors.fill: opacityMaskWrapper
        visible: false
        layer.enabled: true
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: root.horizontalPadding / horizontalClipMask.width; color: "white" }
            GradientStop { position: 1 - root.horizontalPadding / horizontalClipMask.width; color: "white" }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    
    MultiEffect {
        maskEnabled: true
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        anchors.fill: opacityMaskWrapper
        source: opacityMaskWrapper
        maskSource: horizontalClipMask
    }

    QtObject {
        id: d
        property string hoveredUrl: ""
        property SortFilterProxyModel filteredModel: SortFilterProxyModel {
            id: filteredModel
            sourceModel: root.linkPreviewModel
            filters: [
                ExpressionFilter {
                    expression: !model.immutable || model.unfurled // Filter out immutable links that haven't been unfurled yet
                }
            ]
        }
    }

    LinkPreviewSettingsCardMenu {
        id: settingsContextMenu

        onEnableLinkPreviewForThisMessage: root.enableLinkPreviewForThisMessage()
        onEnableLinkPreview: root.enableLinkPreview()
        onDisableLinkPreview: root.disableLinkPreview()
    }
}
