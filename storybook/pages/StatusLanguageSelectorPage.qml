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
            property var activeLanguages: [ctrlCurrentLanguage.text]

            anchors.centerIn: parent
            enabled: ctrlEnabled.checked
            languageCodes: ctrlLanguageCodes.text.split(',')
            activeLanguageCodes: activeLanguages
            selectMultiple: ctrlMultipleSelection.checked
            disabledLanguageCodes: selectMultiple ? [ctrlCurrentLanguage.text] : []
            Binding on display {
                when: !ctrlWithIcon.checked
                value: Button.TextOnly
            }

            onLanguageSelected: function(languageCode) {
                if (selectMultiple)
                    return
                logs.logEvent("onChangeLanguageRequested", ["languageCode"], arguments)
                activeLanguages = [languageCode]
            }
            onLanguageToggled: function(code, checked) {
                if (!selectMultiple)
                    return
                logs.logEvent("onLanguageToggled", ["languageCode", "checked"], arguments)
                if (checked) {
                    const active = [...activeLanguages]
                    active.push(code)
                    activeLanguages = active
                } else {
                    const active = [...activeLanguages]
                    active.splice(active.indexOf(code), 1)
                    activeLanguages = active
                }
            }
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 250
        SplitView.preferredHeight: 250

        logsView.logText: logs.logText

        ColumnLayout {
            anchors.fill: parent
            Switch {
                id: ctrlEnabled
                text: "Enabled"
                checked: true
            }
            Switch {
                Layout.leftMargin: 16
                id: ctrlMultipleSelection
                text: "Multiple selection"
                enabled: ctrlEnabled.checked
            }
            Switch {
                id: ctrlWithIcon
                text: "With icon"
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
