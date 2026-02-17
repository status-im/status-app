import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import shared.popups

import Storybook

SplitView {

    Logs { id: logs }

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        PopupBackground {
            anchors.fill: parent
        }

        Button {
            anchors.centerIn: parent
            text: "Reopen"

            onClicked: popup.open()
        }

        ConfirmExternalLinkPopup {
            id: popup

            closePolicy: Popup.CloseOnEscape
            modal: false
            visible: true

            link: "https://cdn.discordapp.com/attachments/1270081474036760627/1471435297182191719/Screenshot_2026-02-12_at_10.18.09.png?ex=69962ca8&is=6994db28&hm=72f720f7479d3b5fe21e484a0e8bdb7daad233abd90eef92e408bba4aa4d493a&"
            domain: "discordapp.com"

            onOpenExternalLink: logs.logEvent("onOpenExternalLink called with link: " + link)
            onSaveDomainToUnfurledWhitelist: logs.logEvent("onSaveDomainToUnfurledWhitelist called with domain: " + domain)
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 200

        logsView.logText: logs.logText
    }
}

// category: Popups
// https://www.figma.com/design/idUoxN7OIW2Jpp3PMJ1Rl8/Settings----Desktop-Legacy?node-id=27093-584044&m=dev
