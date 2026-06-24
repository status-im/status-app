import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models
import Qt5Compat.GraphicalEffects

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups
import StatusQ.Popups.Dialog

import shared.controls
import shared.stores

import AppLayouts.Wallet.views.collectibles

import utils

StatusDialog {
    id: root

    required property string keyUid
    required property bool migratedToColdWallet

    /**
      Format a currency amount, represented as a float `number` as a string, e.g. "1.234",

      @param `symbol` string (optional): e.g. "EUR" or "SNT"; defaults to the current currency short name (locale dependent)
      @param `noSymbolOption` boolean (optional): omits the symbol in the final output

      @return a formatted version of the amount, eg. "1,23 SNT" (decimal separator locale dependent, amount of decimals currency dependent)
    */
    required property var formatBigNumber// => (number:string, symbol?:string, noSymbolOption?:bool) {}

    property Component headerIconComponent

    property bool feesLoading

    property string signButtonText: qsTr("Sign")
    property bool signButtonEnabled: true

    property string closeButtonText: qsTr("Close")

    property date requestTimestamp: new Date()
    property int expirationSeconds
    property bool hasExpiryDate: false

    // Close hidden explicitely until we have persistent notifications in place to reopen this dialog from outside
    property bool headerActionsCloseButtonVisible: bottomSheet // need the close button as we hide the Reject button
    closeHandler: reject // close and emit rejected() signal

    property ObjectModel leftFooterContents
    property ObjectModel rightFooterContents: ObjectModel {
        RowLayout {
            Layout.rightMargin: 4
            spacing: Theme.halfPadding
            StatusFlatButton {
                objectName: "rejectButton"
                Layout.preferredHeight: signButton.height
                visible: (!root.hasExpiryDate || !countdownPill.isExpired) && !root.bottomSheet
                text: qsTr("Reject")
                onClicked: root.reject() // close and emit rejected() signal
            }
            StatusButton {
                objectName: "signButton"
                id: signButton
                interactive: !root.feesLoading && root.signButtonEnabled
                visible: !root.hasExpiryDate || !countdownPill.isExpired
                icon.name: Utils.resolveAuthSignIcon(root.keyUid, root.migratedToColdWallet, Constants.AuthSignPurpose.General)
                disabledColor: Theme.palette.directColor8
                text: root.signButtonText
                onClicked: root.accept() // close and emit accepted() signal
            }
            StatusButton {
                objectName: "closeButton"
                id: closeButton
                visible: root.hasExpiryDate && countdownPill.isExpired
                text: root.closeButtonText
                onClicked: root.close()  // close and emit closed() signal
            }
        }
    }

    property color gradientColor: backgroundColor
    property url fromImageSource
    property alias fromImageSmartIdenticon: fromImageSmartIdenticon
    property url toImageSource
    readonly property alias toImageSmartIdenticon: toImageSmartIdenticon
    property alias headerMainText: headerMainText.text
    readonly property alias headerSubTextLayout: headerSubTextLayout.children
    property string infoTagText
    readonly property alias infoTag: infoTag
    property bool showHeaderDivider: true
    property bool isCollectible
    property bool isCollectibleLoading
    readonly property alias accountSmartIdenticon: accountSmartIdenticon
    readonly property alias collectibleMedia: collectibleMedia

    default property alias contents: contentsLayout.data

    property bool internalPopupActive: false
    property color internalOverlayColor: Theme.palette.backdropColor
    property Component internalPopupComponent

    signal closeInternalPopup()

    width: 480
    padding: 0

    closePolicy: Popup.NoAutoClose

    function requestOpenLink(linkUrl) {
        Global.requestOpenLink(linkUrl)
    }

    header: StatusDialogHeader {
        visible: root.title || root.subtitle
        headline.title: root.title
        headline.subtitle: root.subtitle
        actions.closeButton.visible: root.headerActionsCloseButtonVisible
        actions.closeButton.onClicked: root.closeHandler()

        leftComponent: root.headerIconComponent

        internalPopupActive: root.internalPopupActive
        internalOverlayColor: root.internalOverlayColor
        popupFullHeight: root.height
        internalPopupComponent: root.internalPopupComponent

        onCloseInternalPopup: root.closeInternalPopup()
    }

    footer: StatusDialogFooter {
        dropShadowEnabled: true

        leftButtons: root.leftFooterContents
        rightButtons: root.rightFooterContents
    }

    StatusScrollView {
        id: scrollView
        anchors.fill: parent
        contentWidth: availableWidth
        contentHeight: content.implicitHeight
        topPadding: 0
        bottomPadding: countdownPill.height

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.right: parent.right
            anchors.rightMargin: 4
            spacing: 0

            // header box with gradient
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: -parent.anchors.leftMargin - scrollView.leftPadding
                Layout.rightMargin: -parent.anchors.rightMargin - scrollView.rightPadding
                Layout.preferredHeight: childrenRect.height + 80 - countdownPill.height // 40 + 40 top/bottomMargin
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Utils.setColorAlpha(root.gradientColor, 0.05) }
                    GradientStop { position: 1.0; color: root.backgroundColor }
                }

                ColumnLayout {
                    width: 336 // by design
                    spacing: 12
                    anchors.centerIn: parent

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 4
                        spacing: -10
                        StatusSmartIdenticon {
                            objectName: "fromImageIdenticon"
                            id: fromImageSmartIdenticon
                            width: 40
                            height: 40
                            asset.name: root.fromImageSource
                            asset.width: 40
                            asset.height: 40
                            asset.bgWidth: 40
                            asset.bgHeight: 40
                            asset.color: "transparent"
                            asset.bgColor: "transparent"
                            visible: !!asset.name
                            layer.enabled: toImageSmartIdenticon.visible
                            layer.effect: OpacityMask {
                                id: mask
                                invert: true

                                maskSource: Item {
                                    width: mask.width + 4
                                    height: mask.height + 4

                                    Rectangle {
                                        anchors.centerIn: parent
                                        anchors.horizontalCenterOffset: toImageSmartIdenticon.width - 10

                                        width: parent.width
                                        height: width
                                        radius: width / 2
                                    }
                                }
                            }
                        }

                        StatusSmartIdenticon {
                            objectName: "toImageIdenticon"
                            id: toImageSmartIdenticon
                            width: 40
                            height: 40
                            asset.bgWidth: 40
                            asset.bgHeight: 40
                            visible: !!asset.name || !!asset.source
                            asset.name: root.toImageSource
                            asset.width: 40
                            asset.height: 40
                            asset.color: "transparent"
                            asset.bgColor: "transparent"
                        }
                        visible: !root.isCollectible
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignCenter
                        spacing: -accountSmartIdenticon.width+4
                        Item {
                            height: 120
                            width: 120
                            CollectibleMedia {
                                id: collectibleMedia

                                objectName: "collectibleMedia"
                                manualMaxDimension: 120
                                radius: 12
                                isCollectibleLoading: root.isCollectibleLoading
                            }
                            layer.enabled: true
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 0
                                samples: 37
                                color: Utils.setColorAlpha(root.gradientColor, 0.15)
                            }
                        }
                        Rectangle {
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: -4

                            Layout.preferredWidth: accountSmartIdenticon.width + 4
                            Layout.preferredHeight: accountSmartIdenticon.height + 4
                            radius: width/2
                            color: root.backgroundColor

                            StatusSmartIdenticon {
                                id: accountSmartIdenticon

                                anchors.centerIn: parent
                                objectName: "accountSmartIdenticon"
                                asset.bgWidth: 28
                                asset.bgHeight: 28
                                visible: !!asset.name || !!asset.source
                                asset.width: 28
                                asset.height: 28
                                asset.color: "transparent"
                                asset.bgColor: "transparent"
                            }
                        }
                        visible: root.isCollectible
                    }

                    StatusBaseText {
                        id: headerMainText
                        objectName: "headerText"
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        font.weight: Font.DemiBold
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        horizontalAlignment: Text.AlignHCenter
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 22
                        textFormat: Text.PlainText
                    }

                    RowLayout {
                        id: headerSubTextLayout
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4
                    }

                    InformationTag {
                        id: infoTag
                        Layout.alignment: Qt.AlignHCenter
                        asset.name: "info"
                        tagPrimaryLabel.text: root.infoTagText
                        visible: !!root.infoTagText
                    }
                }

                CountdownPill {
                    id: countdownPill
                    objectName: "countdownPill"
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.padding
                    timestamp: root.requestTimestamp
                    expirationSeconds: root.expirationSeconds
                    visible: !!root.hasExpiryDate
                }
            }

            StatusDialogDivider {
                Layout.fillWidth: true
                Layout.bottomMargin: Theme.bigPadding
                visible: root.showHeaderDivider
            }

            ColumnLayout {
                Layout.fillWidth: true
                id: contentsLayout
            }
        }
    }
}
