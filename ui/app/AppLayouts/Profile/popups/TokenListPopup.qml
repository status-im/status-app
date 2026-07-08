import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups.Dialog
import StatusQ.Core.Theme
import StatusQ.Core.Utils

import utils

import shared.panels

import QtModelsToolkit

StatusAdaptiveDialog {
    id: root

    required property string sourceImage
    required property string sourceUrl
    required property string sourceVersion
    required property double updatedAt
    required property var tokensListModel // Expected roles: name, symbol, image, chainId, blockExplorerURL, isTest

    signal linkClicked(string link)

    QtObject {
        id: d

        readonly property real symbolColumnFraction: 1 / 6
        readonly property real addressColumnFraction: 1 / 5
        readonly property int externalLinkBtnWidth: 32
    }

    subtitle: qsTr("%n token(s)", "", root.tokensListModel.ModelCount.count)
    leftHeaderComponent: StatusSmartIdenticon {
        asset.name: root.sourceImage
        asset.isImage: !!asset.name
    }

    contentComponent: StatusListView {
        id: list

        ScrollBar.vertical: null

        implicitHeight: contentHeight
        model: root.tokensListModel

        header: ColumnLayout {
            spacing: 20
            width: list.width

            CustomSourceInfoComponent {
                Layout.fillWidth: true
            }

            Separator {}

            CustomHeaderDelegate {}
        }
        delegate: CustomDelegate {
            width: ListView.view.width
            height: 64

            name: model.name
            image: model.image
            chainName: model.chainName
            symbol: model.symbol
            address: model.address
            explorerUrl: "%1/token/%2".arg(model.blockExplorerURL).arg(model.address)
            isTest: model.isTest
        }
    }

    footerRightButtons: ObjectModel {
        StatusButton {
            objectName: "tokenListPopupDoneButton"
            text: qsTr("Done")
            onClicked: root.close()
        }
    }

    component CustomTextBlock: ColumnLayout {
        id: textBlock

        property string title
        property string text

        Layout.fillWidth: true

        StatusBaseText {
            Layout.fillWidth: true

            text: textBlock.title
        }

        StatusBaseText {
            Layout.fillWidth: true

            text: textBlock.text
            elide: Text.ElideRight
            color: Theme.palette.baseColor1
        }
    }

    component CustomExternalLinkButton: StatusFlatButton {
        id: extButton

        property string link

        Layout.preferredHeight: d.externalLinkBtnWidth
        Layout.preferredWidth: d.externalLinkBtnWidth

        spacing: 0
        textColor: Theme.palette.baseColor1
        textHoverColor: Theme.palette.directColor1
        icon.name: "external-link"
        onClicked: root.linkClicked(link)
    }

    component CustomSourceInfoComponent: ColumnLayout {
        spacing: 20

        RowLayout {
            spacing: Theme.padding

            CustomTextBlock {
                title: qsTr("Source")
                text: root.sourceUrl
            }

            CustomExternalLinkButton {
                Layout.rightMargin: Theme.halfPadding

                link: root.sourceUrl
            }
        }

        CustomTextBlock {
            title: qsTr("Version")
            text: qsTr("%1 - last updated %2").arg(root.sourceVersion).arg(LocaleUtils.getTimeDifference(new Date(root.updatedAt * 1000), new Date()))
        }
    }

    component CustomHeaderDelegate: RowLayout {
        id: headerDelegate

        height: 34
        width: ListView.view ? ListView.view.width : 0
        spacing: 0

        StatusBaseText {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding

            text: qsTr("Name")
            color: Theme.palette.baseColor1
        }

        StatusBaseText {
            Layout.leftMargin: Theme.padding
            Layout.preferredWidth: headerDelegate.width * d.symbolColumnFraction - Layout.leftMargin
            Layout.alignment: Qt.AlignLeft

            text: qsTr("Symbol")
            color: Theme.palette.baseColor1
        }

        StatusBaseText {
            Layout.leftMargin: Theme.padding
            Layout.preferredWidth: headerDelegate.width * d.addressColumnFraction - Layout.leftMargin
            Layout.alignment: Qt.AlignLeft

            text: qsTr("Address")
            color: Theme.palette.baseColor1
        }

        // Just a filler corresponding to external link column
        Item {
            Layout.leftMargin: Theme.padding
            Layout.preferredWidth: d.externalLinkBtnWidth
            Layout.rightMargin: Theme.bigPadding
        }
    }

    component CustomDelegate: Rectangle {
        id: customDelegate
        implicitWidth: 156
        height: 64
        color: (sensor.hovered || externalLinkBtn.hovered) ? Theme.palette.baseColor2 : "transparent"
        radius: Theme.radius

        property string name
        property string image
        property string chainName
        property string symbol
        property string address
        property string explorerUrl
        property bool isTest

        HoverHandler {
            id: sensor
        }

        RowLayout {
            spacing: 0
            anchors.fill: parent

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: Theme.padding
                spacing: Theme.padding

                StatusRoundedImage {
                    image.source: customDelegate.image || Constants.tokenIcon(customDelegate.symbol)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter

                    spacing: 0

                    StatusBaseText {
                        Layout.fillWidth: true

                        text: customDelegate.name
                        elide: Text.ElideMiddle
                    }

                    StatusBaseText {
                        Layout.fillWidth: true

                        text: customDelegate.chainName + (customDelegate.isTest? " " + qsTr("(Test)") : "")
                        elide: Text.ElideMiddle
                        color: Theme.palette.baseColor1
                    }
                }
            }

            StatusBaseText {
                Layout.leftMargin: Theme.padding
                Layout.preferredWidth: customDelegate.width * d.symbolColumnFraction - Layout.leftMargin
                Layout.alignment: Qt.AlignLeft

                text: customDelegate.symbol
                elide: Text.ElideMiddle
            }

            StatusBaseText {
                Layout.leftMargin: Theme.padding
                Layout.preferredWidth: customDelegate.width * d.addressColumnFraction - Layout.leftMargin
                Layout.alignment: Qt.AlignLeft

                text: customDelegate.address
                elide: Text.ElideMiddle
            }

            CustomExternalLinkButton {
                id: externalLinkBtn

                Layout.leftMargin: Theme.padding
                Layout.rightMargin: Theme.bigPadding

                link: customDelegate.explorerUrl
            }
        }
    }
}
