import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import utils
import shared.panels
import shared.stores.send

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components
//TODO improve this!
import AppLayouts.Chat.stores as ChatStores

StatusDropdown {
    id: root

    property ChatStores.RootStore store

    property alias isWalletEnabled: stickerMarket.isWalletEnabled
    property bool thirdpartyServicesEnabled
    signal enableThirdpartyServicesRequested

    signal stickerSelected(string hashId, string packId, string url)
    signal buyClicked(string packId, string price)

    QtObject {
        id: d

        // FIXME: move me to store
        readonly property int installedPacksCount: root.store.stickersModuleInst.numInstalledStickerPacks
        readonly property var recentStickers: root.store.stickersModuleInst.recent
        readonly property var stickerPackList: store.stickersModuleInst.stickerPacks
        readonly property bool stickerPacksLoaded: store.stickersModuleInst.packsLoaded
        readonly property bool stickerPacksLoadFailed: store.stickersModuleInst.packsLoadFailed
        readonly property bool stickerPacksLoading: !stickerPacksLoaded && !stickerPacksLoadFailed

        function loadStickers() {
            store.stickersModuleInst.loadStickers()
        }

        function getRecentStickers() {
            store.stickersModuleInst.getRecentStickers()
        }

        function getInstalledStickerPacks() {
            store.stickersModuleInst.getInstalledStickerPacks()
        }

        readonly property bool online: root.store.networkConnectionStore.isOnline
        onOnlineChanged: {
            if (online)
                d.loadStickers()
        }
    }

    enabled: !!d.recentStickers && !!d.stickerPackList
    width: 360
    height: 440
    background: Rectangle {
        radius: Theme.radius
        color: Theme.palette.background
        border.color: Theme.palette.border
        layer.enabled: true
        layer.effect: DropShadow {
            verticalOffset: 3
            radius: 8
            samples: 15
            fast: true
            cached: true
            color: "#22000000"
        }
    }

    onAboutToShow: {
        d.getInstalledStickerPacks()
        if (!stickerGrid.packId) {
            d.getRecentStickers()
        }
    }

    onClosed: {
        stickerMarket.visible = false
        footerContent.visible = true
        stickersContainer.visible = true
    }

    padding: 0

    contentItem: ColumnLayout {
        spacing: 0

        StatusStickerMarket {
            id: stickerMarket

            visible: false
            Layout.fillWidth: true
            Layout.fillHeight: true
            store: root.store
            stickerPacks: d.stickerPackList
            packId: stickerPackListView.selectedPackId
            marketVisible: root.thirdpartyServicesEnabled && d.stickerPacksLoaded
                           && d.online
            onInstallClicked: {
                //starts async task
                stickersModule.install(packId)
            }
            onUninstallClicked: {
                stickersModule.uninstall(packId)
                stickerGrid.model = d.recentStickers
                btnHistory.clicked(null)
            }
            onBackClicked: {
                stickerMarket.visible = false
                footerContent.visible = true
                stickersContainer.visible = true
            }
            onBuyClicked: root.buyClicked(packId, price)

            Connections {
                target: root.store.stickersModuleInst
                function onStickerPackInstalled(packId) {
                    const idx = stickersModule.stickerPacks.findIndexById(packId, false);
                    if (idx === -1) {
                        return
                    }
                    stickersModule.stickerPacks.findStickersById(packId)
                    stickerGrid.model = stickersModule.stickerPacks.getFoundStickers()
                    stickerPackListView.itemAt(idx).clicked()
                }
            }

            Loader {
                id: marketLoader
                anchors.centerIn: parent
                active: d.stickerPacksLoading
                sourceComponent: loadingImageComponent
            }

            ColumnLayout {
                id: failedToLoadStickersInfo

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.padding

                visible: root.thirdpartyServicesEnabled && d.stickerPacksLoadFailed || !d.online
                spacing: Theme.padding

                StatusBaseText {
                    Layout.fillWidth: true

                    wrapMode: Text.Wrap
                    text: qsTr("Failed to load stickers")
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.palette.dangerColor1
                }

                StatusButton {
                    objectName: "stickersPopupRetryButton"
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Try again")
                    enabled: d.online

                    onClicked: d.loadStickers()
                }
            }


            ColumnLayout {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.padding

                visible: !root.thirdpartyServicesEnabled
                spacing: Theme.padding

                StatusBaseText {
                    Layout.fillWidth: true

                    wrapMode: Text.Wrap
                    text: qsTr("Enable third-party services for stickers feature to work.")
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.palette.dangerColor1
                }

                StatusButton {
                    Layout.alignment: Qt.AlignHCenter

                    type: StatusBaseButton.Type.Primary
                    normalColor: Theme.palette.privacyColors.primary
                    textColor: Theme.palette.privacyColors.tertiary

                    text: qsTr("Enable third-party services")

                    onClicked: root.enableThirdpartyServicesRequested()
                }
            }
        }

        Item {
            id: stickersContainer
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.topMargin: 4
            Layout.bottomMargin: 0
            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
            Layout.preferredHeight: 400 - 4

            Item {
                id: noStickerPacks
                anchors.fill: parent
                visible: d.installedPacksCount == 0 && stickersModule.recent.rowCount() === 0

                Image {
                    id: imgNoStickers
                    width: 56
                    height: 56
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 134
                    source: Assets.svg("stickers_sad_icon")
                }

                Item {
                    id: noStickersContainer
                    width: parent.width
                    height: 22
                    anchors.top: imgNoStickers.bottom
                    anchors.topMargin: 8

                    StyledText {
                        id: lblNoStickersYet
                        anchors.fill: parent
                        font.pixelSize: Theme.primaryTextFontSize
                        text: d.installedPacksCount === 0 || !d.online ? qsTr("You don't have any stickers yet")
                                                                       : qsTr("Recently used stickers will appear here")
                        lineHeight: 22
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                StatusButton {
                    objectName: "stickersPopupGetStickersButton"
                    visible: d.installedPacksCount === 0
                    text: qsTr("Get Stickers")
                    enabled: d.online
                    anchors.top: noStickersContainer.bottom
                    anchors.topMargin: Theme.padding
                    anchors.horizontalCenter: parent.horizontalCenter
                    onClicked: {
                        stickersContainer.visible = false
                        stickerMarket.visible = true
                        footerContent.visible = false
                    }
                }
            }

            StatusStickerList {
                id: stickerGrid
                objectName: "statusStickerPopupStickerGrid"
                anchors.fill: parent
                model: d.recentStickers
                packId: stickerPackListView.selectedPackId
                onStickerClicked: {
                    root.stickerSelected(hash, packId, url)
                    root.close()
                }
            }

            Component {
                id: loadingImageComponent
                StatusLoadingIndicator {
                    width: 50
                    height: 50
                }
            }

            Loader {
                id: loadingGrid
                active: d.stickerPacksLoading
                sourceComponent: loadingImageComponent
                anchors.centerIn: parent
            }
        }

        RowLayout {
            id: footerContent
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            Layout.rightMargin: Theme.padding / 2
            Layout.leftMargin: Theme.padding / 2
            spacing: Theme.padding / 2

            StatusRoundButton {
                id: btnAddStickerPack
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                icon.name: "add"
                type: StatusFlatRoundButton.Type.Secondary
                loading: d.stickerPacksLoading
                onClicked: {
                    stickersContainer.visible = false
                    stickerMarket.visible = true
                    footerContent.visible = false
                }
            }

            StatusTabBarIconButton {
                id: btnHistory
                icon.name: "time"
                highlighted: true
                onClicked: {
                    highlighted = true
                    stickerPackListView.selectedPackId = ""
                    d.getRecentStickers()
                    stickerGrid.model = d.recentStickers
                }
            }

            StatusScrollView {
                id: scrollView

                Layout.fillWidth: true
                Layout.fillHeight: true
                padding: 0
                contentHeight: availableHeight
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                RowLayout {
                    height: scrollView.availableHeight
                    spacing: footerContent.spacing

                    Repeater {
                        id: stickerPackListView
                        property string selectedPackId
                        model: d.stickerPackList
                        visible: d.stickerPacksLoaded

                        delegate: StatusStickerPackIconWithIndicator {
                            id: packIconWithIndicator
                            visible: installed
                            Layout.alignment: Qt.AlignVCenter
                            selected: stickerPackListView.selectedPackId === packId
                            source: thumbnail
                            onClicked: {
                                btnHistory.highlighted = false
                                stickerPackListView.selectedPackId = packId
                                stickerGrid.model = stickers
                            }
                        }
                    }
                    Repeater {
                        id: loadingStickerPackListView
                        model: d.stickerPacksLoading ? 7 : 0

                        delegate: Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            radius: width / 2
                            color: Theme.palette.backgroundHover
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}

