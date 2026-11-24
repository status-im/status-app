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
import mainui.sectionLoaders
import shared.stores as SharedStores

SplitView {
    id: root
    Logs { id: logs }

    PopupsLoader {
        keychain: Keychain {}
        secureStorage: SecureStorage { service: "StatusStorybook.AutoLogin" }
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
            pullToRefreshEnabled: ctrlPullToRefreshEnabled.checked

            onCuratedRefreshRequested: {
                logs.logEvent("CommunitiesPortalLayout::curatedRefreshRequested")
                if (ctrlRefreshOnRequest.checked)
                    ctrlCuratedCommunitiesLoading.checked = true
            }

            assetsModel: AssetsModel {}
            collectiblesModel: CollectiblesModel {}
            communitiesStore: CommunitiesStore {
                readonly property string communityTags: ModelsData.communityTags

                curatedCommunitiesLoading: ctrlCuratedCommunitiesLoading.checked
                curatedCommunitiesRefreshError: ctrlCuratedRefreshError.checkedButton.value

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
                id: localAccountSettings
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
                        objectName: "ctrlCommunitiesCount"
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

                Switch {
                    id: ctrlCuratedCommunitiesLoading
                    objectName: "ctrlCuratedCommunitiesLoading"
                    text: "Curated communities loading"
                }

                Row {
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "refresh error:"
                    }

                    ButtonGroup {
                        id: ctrlCuratedRefreshError
                    }

                    RadioButton {
                        readonly property int value: Constants.CuratedCommunitiesRefreshError.None

                        objectName: "ctrlCuratedRefreshErrorNone"
                        text: "None"
                        checked: true
                        ButtonGroup.group: ctrlCuratedRefreshError
                    }

                    RadioButton {
                        readonly property int value: Constants.CuratedCommunitiesRefreshError.Partial

                        objectName: "ctrlCuratedRefreshErrorPartial"
                        text: "Partial"
                        ButtonGroup.group: ctrlCuratedRefreshError
                    }

                    RadioButton {
                        readonly property int value: Constants.CuratedCommunitiesRefreshError.Full

                        objectName: "ctrlCuratedRefreshErrorFull"
                        text: "Full"
                        ButtonGroup.group: ctrlCuratedRefreshError
                    }
                }

                Switch {
                    id: ctrlPullToRefreshEnabled
                    objectName: "ctrlPullToRefreshEnabled"
                    text: "Pull to refresh enabled (touch platforms)"
                }

                Switch {
                    id: ctrlRefreshOnRequest
                    objectName: "ctrlRefreshOnRequest"
                    text: "A requested refresh starts loading"
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
