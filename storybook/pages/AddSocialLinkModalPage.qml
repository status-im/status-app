import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Profile.popups

import Storybook

SplitView {
    id: root

    orientation: Qt.Vertical

    Logs {
        id: logs
    }

    ListModel {
        id: existingLinksModel

        ListElement {
            text: "__github"
            url: "https://github.com/status-im"
        }
        ListElement {
            text: "__twitter"
            url: "https://twitter.com/ethstatus"
        }
        ListElement {
            text: "Docs"
            url: "https://docs.status.im"
        }
    }

    Component {
        id: addSocialLinkModalComponent

        AddSocialLinkModal {
            containsSocialLink: (text, url) => {
                                    if (!duplicateValidationCheck.checked)
                                        return false

                                    const linkText = text.toLowerCase()
                                    const linkUrl = url.toLowerCase()
                                    for (let i = 0; i < existingLinksModel.count; i++) {
                                        const entry = existingLinksModel.get(i)
                                        if (entry.text.toLowerCase() === linkText &&
                                                entry.url.toLowerCase() === linkUrl) {
                                            return true
                                        }
                                    }
                                    return false
                                }

            onAddLinkRequested: (linkText, linkUrl, linkType, linkIcon) => {
                                    logs.logEvent("AddSocialLinkModal::addLinkRequested",
                                                  ["linkText", "linkUrl", "linkType", "linkIcon"],
                                                  [linkText, linkUrl, linkType, linkIcon])
                                    existingLinksModel.append({ text: linkText, url: linkUrl })
                                }
        }
    }

    PopupBackground {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Button {
            anchors.centerIn: parent
            text: "Open"
            onClicked: root.openModal()
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 140
        SplitView.preferredHeight: 220

        logsView.logText: logs.logText

        ColumnLayout {
            CheckBox {
                id: duplicateValidationCheck

                text: "Enable duplicate validation"
                checked: true
            }

            Button {
                text: "Open"
                onClicked: root.openModal()
            }
        }
    }

    function openModal() {
        const popup = addSocialLinkModalComponent.createObject(root)
        popup.open()
    }

    Component.onCompleted: openModal()
}

// category: Popups
// status: good
