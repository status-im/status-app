import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils
import StatusQ.Core
import StatusQ.Components
import StatusQ.Core.Theme

import AppLayouts.Communities.views

Item {
    id: root

    property var holdingsModel
    property var assetsModel
    property var collectiblesModel

    QtObject {
        id: d
        property int panelRowSpacing: 4 // by design
    }

    RowLayout {
        anchors.fill: parent
        spacing: d.panelRowSpacing
        StatusBaseText {
            text: qsTr("To post, hold")
            font.pixelSize: Theme.primaryTextFontSize
            color: Theme.palette.secondaryText
        }

        StatusScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            contentWidth: tokenRow.implicitWidth
            padding: 0
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            Row {
                id: tokenRow
                Repeater {
                    id: repeater
                    model: root.holdingsModel
                    Row {
                        spacing: d.panelRowSpacing
                        Row {
                            spacing: d.panelRowSpacing
                            Repeater {
                                model: HoldingsSelectionModel {
                                    sourceModel: holdingsListModel
                                    assetsModel: root.assetsModel
                                    collectiblesModel: root.collectiblesModel
                                }
                                StatusListItemTag {
                                    height: 20
                                    enabled: false
                                    leftPadding: 2
                                    title: model.text
                                    asset.name: model.imageSource || ""
                                    asset.isImage: true
                                    asset.bgColor: "transparent"
                                    asset.height: 16
                                    asset.width: asset.height
                                    asset.bgWidth: asset.height
                                    asset.bgHeight: asset.height
                                    asset.color: asset.isImage ? "transparent" : titleText.color
                                    closeButtonVisible: false
                                    titleText.color: model.available ? Theme.palette.primaryColor1 : Theme.palette.dangerColor1
                                    bgColor: model.available ? Theme.palette.primaryColor2 :Theme.palette.dangerColor2
                                    titleText.font.pixelSize: Theme.tertiaryTextFontSize
                                }
                            }
                        }
                        StatusBaseText {
                            height: parent.height
                            visible: (index !== (repeater.count - 1))
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: Theme.primaryTextFontSize
                            rightPadding: d.panelRowSpacing
                            color: Theme.palette.secondaryText
                            text: qsTr("or")
                        }
                    }
                }
            }
        }
        Item { Layout.fillWidth: true }
    }
}
