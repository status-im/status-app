import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ

import mainui
import AppLayouts.stores as AppLayoutStores
import AppLayouts.Communities.panels

import shared.stores as SharedStores

import Models

SplitView {
    id: root
    SplitView.fillWidth: true

    Keychain {
        id: popupsKeychain
    }

    Popups {
        keychain: popupsKeychain
        popupParent: root
        sharedRootStore: SharedStores.RootStore {}
        rootStore: AppLayoutStores.RootStore {}
        communityTokensStore: SharedStores.CommunityTokensStore {}
        networksStore: SharedStores.NetworksStore {}
    }

    ColumnLayout {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Button {
            text: "<-- Back to %1".arg(panel.previousPageName)
            visible: panel.currentIndex !== 0
            onClicked: panel.navigateBack()
        }

        OverviewSettingsPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true

            id: panel

            communityId: "commId"
            name: communityEditor.name
            description: communityEditor.description
            logoImageData: communityEditor.image
            color: communityEditor.color
            bannerImageData: communityEditor.banner
            tags: ModelsData.communityTags

            isOwner: communityEditor.amISectionAdmin
            isAdmin: ctrlIsAdmin.checked
            isTokenMaster: ctrlIsTM.checked

            editable: communityEditor.isCommunityEditable
            communitySettingsDisabled: !editable

            isPendingOwnershipRequest: pendingOwnershipSwitch.checked

            isControlNode: ctrlControlNode.checked
            isTokenDeployed: ctrlTokenDeployed.checked

            isMobile: ctrlIsMobile.checked

            onCollectCommunityMetricsMessagesCount: (intervals) => generateRandomModel(intervals)
        }
    }

    function generateRandomModel(intervalsStr) {
        if(!intervalsStr) return

        var response = {
            communityId: panel.communityId,
            metricsType: "MessagesCount",
            intervals: []
        }

        var intervals = JSON.parse(intervalsStr)

        response.intervals = intervals.map( x => {
            var timestamps = generateRandomDate(x.startTimestamp, x.endTimestamp, Math.random() * 10)

            return {
                startTimestamp: x.startTimestamp,
                endTimestamp: x.endTimestamp,
                timestamps: timestamps,
                count: timestamps.length
            }
        })

        panel.overviewChartData = JSON.stringify(response)
    }

    function generateRandomDate(from, to, count) {
        var newModel = []
        for(var i = 0; i < count; i++) {
            var date = from + Math.random() * (to - from)
            newModel.push(date)
        }
        return newModel
    }

    Pane {
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 300

        ScrollView {
            anchors.fill: parent
            contentWidth: availableWidth

            CommunityInfoEditor {
                id: communityEditor

                Switch {
                    id: ctrlControlNode
                    text: "Is control node?"
                    checked: true
                }

                Switch {
                    id: ctrlIsMobile
                    text: "Is mobile?"
                }

                Switch {
                    id: ctrlTokenDeployed
                    text: "Token deployed?"
                }

                Switch {
                    id: pendingOwnershipSwitch
                    text: "Pending transfer ownership request?"
                }

                Switch {
                    id: ctrlIsAdmin
                    text: "Is admin?"
                }

                Switch {
                    id: ctrlIsTM
                    text: "Is token master?"
                }
            }
        }
    }
}

// category: Panels
// status: good
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba⎜Desktop?type=design&node-id=31229-627216&mode=design&t=KoQOW7vmoNc7f41m-0
