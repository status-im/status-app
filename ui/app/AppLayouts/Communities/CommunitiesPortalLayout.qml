import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups.Dialog
import StatusQ.Layout

import utils
import shared.controls
import shared.popups
import shared.stores

import SortFilterProxyModel

import AppLayouts.Communities.controls
import AppLayouts.Communities.popups
import AppLayouts.Communities.views
import AppLayouts.Communities.panels
import AppLayouts.Communities.stores

StatusSectionLayout {
    id: root

    property CommunitiesStore communitiesStore

    property var assetsModel
    property var collectiblesModel

    property bool createCommunityEnabled: true

    objectName: "communitiesPortalLayout"

    QtObject {
        id: d

        // values from the design
        readonly property int layoutTopMargin: root.Theme.smallPadding
        readonly property int layoutBottomMargin: root.Theme.xlPadding*2
        readonly property int titlePixelSize: root.Theme.fontSize(28)
 
        readonly property bool searchMode: searcher.text.length > 0

        // Read-only flag that turns true when the component enters a “compact” layout automatically on resize.
        readonly property bool compactMode: root.width < 600
        readonly property int stateContentWidth: Math.min(560, Math.max(0, root.width - Theme.xlPadding * 4))
        readonly property bool curatedCommunitiesLoading: root.communitiesStore.curatedCommunitiesLoading
        readonly property bool curatedCommunitiesLoadingFailed: root.communitiesStore.curatedCommunitiesLoadingFailed
        readonly property bool curatedCommunitiesBlockedByNetwork: root.communitiesStore.isExpensiveNetwork
                                                                && !root.communitiesStore.curatedCommunitiesLoaded
                                                                && !d.curatedCommunitiesLoadingFailed
                                                                && !d.curatedCommunitiesLoading
    }

    SortFilterProxyModel {
        id: filteredCommunitiesModel

        function selectedTagsPredicate(selectedTagsNames, tagsJSON) {
            if (!tagsJSON) {
                return true
            }
            const tags = JSON.parse(tagsJSON)
            for (const i in tags) {
                selectedTagsNames = selectedTagsNames.filter(name => name !== tags[i].name)
            }
            return selectedTagsNames.length === 0
        }

        sourceModel: root.communitiesStore.curatedCommunitiesModel

        filters: [
            SQUtils.SearchFilter {
                roleName: "name"
                searchPhrase: searcher.text
            },
            FastExpressionFilter {
                expression: {
                    return filteredCommunitiesModel.selectedTagsPredicate(communityTags.selectedTagsNames, model.tags)
                }
                expectedRoles: ["tags"]
            },
            ValueFilter {
                roleName: "amIBanned"
                value: false
            }
        ]
    }

    Connections {
        target: root.communitiesStore

        function onIsExpensiveNetworkChanged() {
            if (!root.communitiesStore.isExpensiveNetwork && !root.communitiesStore.curatedCommunitiesLoaded) {
                root.communitiesStore.requestCuratedCommunitiesLoad()
            }
        }
    }

    centerPanel: Item {
        anchors.fill: parent

        anchors.topMargin: d.layoutTopMargin
        anchors.leftMargin: Theme.xlPadding

        ColumnLayout {
            id: column

            anchors.fill: parent
            spacing: 18

            StatusBaseText {
                Layout.fillWidth: true
                text: qsTr("Discover Communities")
                font.weight: Font.Bold
                font.pixelSize: d.titlePixelSize
                color: Theme.palette.directColor1
                elide: Text.ElideRight
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }

            ColumnLayout {
                spacing: Theme.padding
                Layout.fillWidth: true
                Layout.rightMargin: Theme.xlPadding

                RowLayout {
                    SearchBox {
                        id: searcher
                        Layout.fillWidth: true
                        Layout.maximumWidth: 327
                        Layout.preferredHeight: 38
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // filler
                    Item {
                        Layout.fillWidth: true
                    }

                    LayoutItemProxy {
                        visible: !d.compactMode

                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter

                        target: buttonsRow
                    }
                }

                LayoutItemProxy {
                    visible: d.compactMode

                    Layout.fillWidth: true

                    target: buttonsRow
                }
            }

            ColumnLayout {
                visible: d.curatedCommunitiesBlockedByNetwork
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: d.stateContentWidth
                Layout.fillHeight: true
                spacing: Theme.bigPadding

                Item {
                    Layout.fillHeight: true
                }

                StatusBaseText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: qsTr("You are currently on a network that is considered expensive.\nLoading curated communities can be data heavy, so it is disabled by default.")
                    color: Theme.palette.baseColor1
                }

                StatusButton {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Load curated communities anyway")
                    type: StatusBaseButton.Type.Primary
                    onClicked: root.communitiesStore.requestCuratedCommunitiesLoad()
                }

                Item {
                    Layout.fillHeight: true
                }
            }

            ColumnLayout {
                visible: d.curatedCommunitiesLoading
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: d.stateContentWidth
                Layout.fillHeight: true
                spacing: Theme.padding

                Item {
                    Layout.fillHeight: true
                }

                StatusLoadingIndicator {
                    Layout.alignment: Qt.AlignHCenter
                }

                StatusBaseText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: qsTr("Loading curated communities...")
                    color: Theme.palette.baseColor1
                }

                Item {
                    Layout.fillHeight: true
                }
            }

            ColumnLayout {
                visible: d.curatedCommunitiesLoadingFailed
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: d.stateContentWidth
                Layout.fillHeight: true
                spacing: Theme.bigPadding

                Item {
                    Layout.fillHeight: true
                }

                StatusBaseText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: qsTr("Couldn't load curated communities. Please try again.")
                    color: Theme.palette.baseColor1
                }

                StatusButton {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Retry")
                    type: StatusBaseButton.Type.Primary
                    onClicked: root.communitiesStore.requestCuratedCommunitiesLoad()
                }

                Item {
                    Layout.fillHeight: true
                }
            }

            TagsRow {
                id: communityTags
                visible: !d.curatedCommunitiesBlockedByNetwork && !d.curatedCommunitiesLoading && !d.curatedCommunitiesLoadingFailed
                Layout.fillWidth: true
                Layout.rightMargin: Theme.xlPadding

                tags: root.communitiesStore.communityTags
            }

            CommunitiesGridView {
                id: communitiesGrid
                visible: !d.curatedCommunitiesBlockedByNetwork && !d.curatedCommunitiesLoading && !d.curatedCommunitiesLoadingFailed

                Layout.fillWidth: true
                Layout.fillHeight: true

                padding: 0
                bottomPadding: d.layoutBottomMargin
                compactMode: d.compactMode

                model: filteredCommunitiesModel
                searchLayout: d.searchMode

                assetsModel: root.assetsModel
                collectiblesModel: root.collectiblesModel

                onCardClicked: (communityId) => root.communitiesStore.navigateToCommunity(communityId)
            }
        }
    }

    RowLayout {
        id: buttonsRow
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        spacing: Theme.bigPadding

        StatusButton {
            objectName: "joinCommunityButton"
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            Layout.maximumWidth: implicitWidth
            text: qsTr("Join Community")
            verticalPadding: 0
            onClicked: Global.importCommunityPopupRequested()
        }

        StatusButton {
            objectName: "createCommunityButton"
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            Layout.maximumWidth: implicitWidth
            visible: root.createCommunityEnabled
            verticalPadding: 0
            text: qsTr("Create New Community")
            type: StatusBaseButton.Type.Primary
            onClicked: {
                // Global.openPopup(chooseCommunityCreationTypePopupComponent) // hidden as part of https://github.com/status-im/status-app/issues/17726
                Global.createCommunityPopupRequested(false /*isDiscordImport*/)
            }
        }
    }

    // hidden as part of https://github.com/status-im/status-app/issues/17726
    // Component {
    //     id: chooseCommunityCreationTypePopupComponent
    //     StatusDialog {
    //         id: chooseCommunityCreationTypePopup
    //         title: qsTr("Create new community")
    //         horizontalPadding: 40
    //         verticalPadding: 60
    //         footer: null
    //         onClosed: destroy()

    //         contentItem: RowLayout {
    //             spacing: 20
    //             BannerPanel {
    //                 objectName: "createCommunityBanner"
    //                 text: qsTr("Create a new Status community")
    //                 buttonText: qsTr("Create new")
    //                 icon.name: "favourite"
    //                 onButtonClicked: {
    //                     chooseCommunityCreationTypePopup.close()
    //                     Global.createCommunityPopupRequested(false /*isDiscordImport*/)
    //                 }
    //             }
    //             BannerPanel {
    //                 readonly property bool importInProgress: root.communitiesStore.discordImportInProgress && !root.communitiesStore.discordImportCancelled
    //                 text: importInProgress ?
    //                           qsTr("'%1' import in progress...").arg(root.communitiesStore.discordImportCommunityName || root.communitiesStore.discordImportChannelName) :
    //                           qsTr("Import existing Discord community into Status")
    //                 buttonText: qsTr("Import existing")
    //                 icon.name: "download"
    //                 buttonTooltipText: qsTr("Your current import must be finished or cancelled before a new import can be started.")
    //                 buttonLoading: importInProgress
    //                 onButtonClicked: {
    //                     chooseCommunityCreationTypePopup.close()
    //                     Global.createCommunityPopupRequested(true /*isDiscordImport*/)
    //                 }
    //             }
    //         }
    //     }
    // }
}
