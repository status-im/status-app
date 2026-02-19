import QtQuick
import QtQuick.Controls

import AppLayouts.stores as AppLayoutStores
import AppLayouts.Communities
import AppLayouts.Communities.stores

import StatusQ
import SortFilterProxyModel

import Storybook
import Models

import utils
import mainui
import shared.stores as SharedStores

SplitView {
    id: root
    Logs { id: logs }

    Popups {
        popupParent: root
        sharedRootStore: SharedStores.RootStore {}
        rootStore: AppLayoutStores.RootStore {}
        communityTokensStore: SharedStores.CommunityTokensStore {}
        networksStore: SharedStores.NetworksStore {}
    }

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true

        CommunitiesPortalLayout {
            SplitView.fillWidth: true
            SplitView.fillHeight: true

            createCommunityEnabled: ctrlCommunityCreationEnabled.checked

            assetsModel: AssetsModel {}
            collectiblesModel: CollectiblesModel {}
            communitiesStore: CommunitiesStore {
                readonly property string communityTags: ModelsData.communityTags

                readonly property var curatedCommunitiesModel: SortFilterProxyModel {
                    sourceModel: CommunitiesPortalDummyModel { id: mockedModel }

                    filters: IndexFilter {
                        inverted: true
                        minimumIndex: Math.floor(slider.value)
                    }
                }

                function navigateToCommunity() {
                    logs.logEvent("CommunitiesStore::navigateToCommunity", ["communityId"], arguments)
                }
            }

            QtObject {
                id: localAccountSensitiveSettings
                readonly property bool isDiscordImportToolEnabled: false
            }
        }

        LogsAndControlsPanel {
            id: logsAndControlsPanel

            SplitView.minimumHeight: 100
            SplitView.preferredHeight: 200

            logsView.logText: logs.logText

            Column {
                Row {
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "number of communities:"
                    }

                    Slider {
                        id: slider
                        value: 9
                        from: 0
                        to: 9
                    }
                }

                Switch {
                    id: ctrlCommunityCreationEnabled
                    text: "Community creation enabled"
                    checked: true
                }
            }
        }
    }

    Pane {
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 300

        CommunitiesPortalModelEditor {
            anchors.fill: parent
            model: mockedModel
        }
    }
}

// category: Views
// status: good
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=8159%3A415655
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=8159%3A415935
// https://www.figma.com/design/qHfFm7C9LwtXpfdbxssCK3/Kuba%E2%8E%9CDesktop---Communities?node-id=55276-394164&m=dev
