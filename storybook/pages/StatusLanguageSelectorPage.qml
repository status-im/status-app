import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core
import StatusQ.Controls
import StatusQ.Components

import Storybook

import utils

SplitView {
    id: root
    orientation: Qt.Vertical

    Logs { id: logs }

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        StatusLanguageSelector {
            anchors.centerIn: parent
            enabled: ctrlEnabled.checked
            languageCodes: ctrlLanguageCodes.text.split(',')
            activeLanguageCodes: [ctrlCurrentLanguage.text]
            onLanguageSelected: function(languageCode) {
                logs.logEvent("onChangeLanguageRequested", ["languageCode"], arguments)
                activeLanguageCodes = [languageCode]
            }
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 200
        SplitView.preferredHeight: 200

        logsView.logText: logs.logText

        ColumnLayout {
            anchors.fill: parent
            Switch {
                id: ctrlEnabled
                text: "Enabled"
                checked: true
            }
            RowLayout {
                Layout.fillWidth: true
                Label { text: "Current language:" }
                TextField {
                    Layout.preferredWidth: 150
                    id: ctrlCurrentLanguage
                    text: "cs"
                    placeholderText: "Current language code"
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Label { text: "Available languages:" }
                TextField {
                    Layout.fillWidth: true
                    id: ctrlLanguageCodes
                    text: "es,de,de-CH,cs,en,en_CA,ko,ar,fr,fr_CA,pt_BR,pt,uk,ja,el,xx_XX" // last one is invalid, should not appear in the list
                    placeholderText: "Comma separated list of language codes"
                }
            }
        }
    }
}

// category: Components
// status: good
// https://www.figma.com/design/Lw4nPYQcZOPOwTgETiiIYo/Onboarding----Desktop-Legacy?node-id=6769-4202&m=dev
// https://www.figma.com/design/Lw4nPYQcZOPOwTgETiiIYo/Onboarding----Desktop-Legacy?node-id=6769-4423&m=dev
