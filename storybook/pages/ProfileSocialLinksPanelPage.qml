import QtQuick
import QtQuick.Controls

import StatusQ.Core

import mainui
import AppLayouts.stores as AppLayoutStores
import AppLayouts.Profile.panels
import shared.stores as SharedStores

import utils

import Storybook

SplitView {
    id: root

    Logs { id: logs }

    orientation: Qt.Vertical

    Popups {
        popupParent: root
        sharedRootStore: SharedStores.RootStore {}
        rootStore: AppLayoutStores.RootStore {}
        communityTokensStore: SharedStores.CommunityTokensStore {}
        networksStore: SharedStores.NetworksStore {}
    }

    ListModel {
        id: emptyModel
    }

    ListModel {
        id: linksModel
        ListElement {
            uuid: "0001"
            text: "__github"
            url: "https://github.com/caybro"
        }
        ListElement {
            uuid: "0002"
            text: "__twitter"
            url: "https://twitter.com/caybro"
        }
        ListElement {
            uuid: "0003"
            text: "__personal_site"
            url: "https://status.im"
        }
        ListElement {
            uuid: "0004"
            text: "__youtube"
            url: "https://www.youtube.com/@LukasTinkl"
        }
        ListElement { // NB: empty on purpose, for testing
            uuid: ""
            text: ""
            url: ""
        }
        ListElement {
            uuid: "0005"
            text: "Figma design very long URL link text that should elide"
            url: "https://www.figma.com/file/idUoxN7OIW2Jpp3PMJ1Rl8/%E2%9A%99%EF%B8%8F-Settings-%7C-Desktop?node-id=1223%3A124882&t=qvYeJ8grsZLyUS0V-0"
        }
        ListElement {
            uuid: "0006"
            text: "__telegram"
            url: "https://t.me/ltinkl"
        }
    }

    Connections {
        target: Global
        function onRequestOpenLink(link) {
            logs.logEvent("Global::onRequestOpenLink", ["link"], [link])
        }
    }

    StatusScrollView { // wrapped in a ScrollView on purpose; to simulate SettingsContentBase.qml
        SplitView.fillWidth: true
        SplitView.preferredHeight: 500
        ProfileSocialLinksPanel {
            id: socialLinksPanel
            property var linksModel: emptyModelCheck.checked ? emptyModel : linksModel
            width: 500

            onAddSocialLink: {
                logs.logEvent("ProfileSocialLinksPanel::addSocialLink", ["url", "text"], arguments)
                socialLinksPanel.linksModel.append({text: text, url: url})
            }
            onUpdateSocialLink: {
                logs.logEvent("ProfileSocialLinksPanel::updateSocialLink", ["index", "url", "text"], arguments)
                if (!!text)
                    socialLinksPanel.linksModel.setProperty(index, "text", text)
                if (!!url)
                    socialLinksPanel.linksModel.setProperty(index, "url", url)
            }
            onRemoveSocialLink: {
                logs.logEvent("ProfileSocialLinksPanel::removeSocialLink", ["index"], arguments)
                socialLinksPanel.linksModel.remove(index, 1)
            }
            onChangePosition: {
                logs.logEvent("ProfileSocialLinksPanel::changePosition", ["from", "to"], arguments)
                socialLinksPanel.linksModel.move(from, to, 1)
            }

            socialLinksModel: socialLinksPanel.linksModel
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 200

        logsView.logText: logs.logText

        Switch {
            id: emptyModelCheck
            text: "Empty model"
            checked: false
        }
    }
}

// category: Panels
// status: good
// https://www.figma.com/file/idUoxN7OIW2Jpp3PMJ1Rl8/%E2%9A%99%EF%B8%8F-Settings-%7C-Desktop?node-id=14588%3A308727&t=cwFGbBHsAGOP0T5R-0
