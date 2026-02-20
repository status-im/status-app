import QtQuick
import QtQuick.Layouts

import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Popups.Dialog
import StatusQ.Core

import shared.controls

StatusDialog {
    id: root

    required property string link
    required property string domain

    signal openExternalLink(string link)
    signal saveDomainToUnfurledWhitelist(string domain)

    implicitWidth: 521
    padding: Theme.padding

    header: StatusDialogHeader {
        headline.title: qsTr("Opening external link")
        actions.closeButton.onClicked: root.close()
        leftComponent: StatusRoundIcon {
            asset.name: "browser"
            asset.isImage: true
        }
    }

    contentItem: ColumnLayout {
        spacing: Theme.padding
        StatusBaseText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: qsTr("For your privacy, Status asks before opening links, as websites may collect your IP or device information. Copy the link to open it elsewhere, or tap Open to use the browser set in Settings>>Browser>>Open links in")
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            radius: Theme.halfPadding
            color: Theme.palette.baseColor4

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.padding

                spacing: Theme.padding

                StatusBaseText {
                    Layout.fillWidth: true
                    text: root.link
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
                CopyButton {
                    Layout.alignment: Qt.AlignTop
                    textToCopy: root.link
                }
            }
        }

        StatusCheckBox {
            id: trustDomainCheckbox

            Layout.fillWidth: true
            text: qsTr("Always trust links to <b>%1</b>").arg(root.domain)
        }
    }

    footer: StatusDialogFooter {
        bottomPadding: root.padding + root.parent.SafeArea.margins.bottom
        rightButtons: ObjectModel {
            StatusFlatButton {
                text: qsTr("Cancel")
                onClicked: root.close()
            }
            StatusButton {
                text: qsTr("Open")
                onClicked: {
                    // (optionally) save the domain to whitelist
                    if (trustDomainCheckbox.checked) {
                        root.saveDomainToUnfurledWhitelist(root.domain)
                    }

                    root.openExternalLink(root.link)
                    root.close()
                }
            }
        }
    }
}
