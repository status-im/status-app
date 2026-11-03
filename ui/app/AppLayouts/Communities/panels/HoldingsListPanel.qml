import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls

import AppLayouts.Communities.helpers
import AppLayouts.Communities.controls
import AppLayouts.Communities.views

import utils

Control {
    id: root

    property var assetsModel
    property var collectiblesModel
    property var getTokenByKeyOrGroupKeyFromAllTokens: function(key){ return {}}

    property var model
    property string introText

    QtObject {
        id: d

        // By design values:
        readonly property int defaultHoldingsSpacing: 8
    }

    contentItem: ColumnLayout {
        spacing: root.spacing

        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.introText
            textFormat: Text.StyledText
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: d.defaultHoldingsSpacing

            Repeater {
                id: repeater

                model: root.model

                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: d.defaultHoldingsSpacing

                    RowLayout {
                        spacing: 18 // by design

                        Repeater {

                            model: HoldingsSelectionModel {
                                sourceModel: holdingsListModel

                                assetsModel: root.assetsModel
                                collectiblesModel: root.collectiblesModel
                                getTokenByKeyOrGroupKeyFromAllTokens: root.getTokenByKeyOrGroupKeyFromAllTokens
                            }

                            StatusListItemTag {
                                enabled: false
                                leftPadding: 2
                                title: model.text
                                asset.name: model.imageSource
                                asset.isImage: true
                                asset.bgColor: "transparent"
                                asset.height: 28
                                asset.width: asset.height
                                asset.bgWidth: asset.height
                                asset.bgHeight: asset.height
                                asset.color: asset.isImage ? "transparent" : titleText.color
                                closeButtonVisible: false
                                titleText.color: model.available ? Theme.palette.primaryColor1 : Theme.palette.dangerColor1
                                bgColor: model.available ? Theme.palette.primaryColor2 : Theme.palette.dangerColor2
                                titleText.font.pixelSize: Theme.primaryTextFontSize
                            }
                        }
                    }

                    StatusBaseText {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("or")
                        textFormat: Text.StyledText
                        visible: (index !== repeater.count - 1)
                    }
                }
            }
        }
    }
}
