import QtQuick
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme

import QtModelsToolkit

import shared.controls
import utils

import AppLayouts.Profile.popups

StatusListView {
    id: root

    required property var tokenListsModel // Expected roles: id, name, timestamp, source, logoUri, version, tokens
    required property var allNetworks
    property bool loading: false

    implicitHeight: contentHeight
    model: root.tokenListsModel
    spacing: Theme.halfPadding

    header: Item {
        width: root.width
        height: root.loading ? 40 : 0
        visible: root.loading

        StatusLoadingIndicator {
            anchors.centerIn: parent
        }
    }

    delegate: StatusListItem {
        height: ProfileUtils.defaultDelegateHeight
        width: ListView.view.width
        title: model.name
        forceDefaultCursor: true
        subTitle: qsTr("%n token(s) · Last updated %1", "", model.tokens.count).arg(LocaleUtils.getTimeDifference(new Date(model.timestamp * 1000), new Date()))
        statusListItemSubTitle.font.pixelSize: Theme.additionalTextSize
        asset.name: model.logoUri
        asset.isImage: true
        border.width: 1
        border.color: Theme.palette.baseColor5
        highlighted: viewButton.hovered
        components: [
            StatusFlatButton {
                id: viewButton

                text: qsTr("View")
                enabled: !popup.active || popup.status === Loader.Ready
                loading: popup.active && popup.status !== Loader.Ready
                onClicked: popup.open()
            }
        ]

        Loader {
            id: popup

            active: false
            asynchronous: true

            function open() {
                popup.active = true
            }

            function close() {
                popup.active = false
            }

            onLoaded: {
                popup.item.open()
            }

            sourceComponent: TokenListPopup {

                sourceImage: model.logoUri
                sourceUrl: model.source
                sourceVersion: model.version
                updatedAt: model.timestamp

                title: model.name

                tokensListModel: LeftJoinModel {
                    leftModel: model.tokens
                    rightModel: root.allNetworks

                    joinRole: "chainId"
                }

                onLinkClicked: (link) => Global.requestOpenLink(link)
            }
        }
    }
}
