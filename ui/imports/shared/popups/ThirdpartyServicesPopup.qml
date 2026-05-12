import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog
import StatusQ.Controls

import shared.controls

import utils

StatusDialog {
    id: root

    required property bool thirdPartyServicesEnabled
    property bool isOnboardingFlow: false

    signal toggleThirdpartyServicesEnabledRequested()
    signal openDiscussPageRequested()
    signal openThirdpartyServicesArticleRequested()

    implicitWidth: 480
    padding: 0
    title: qsTr("Third-party services")

    StatusScrollView {
        id: scrollView

        anchors.fill: parent
        contentWidth: availableWidth

        padding: 0
        leftPadding: 20
        rightPadding: 20

        ColumnLayout {
            width: scrollView.availableWidth
            spacing: Theme.padding

            Paragraph {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: qsTr("Status uses essential third-party services to make your experience more convenient, efficient, and engaging. While only necessary integrations are included, users who prefer to avoid any third-party services can disable them entirely – though this may limit functionality and affect usability")
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: childrenRect.height

                radius: Theme.radius
                border.width: 1
                border.color: Theme.palette.baseColor2
                color: StatusColors.transparent

                ColumnLayout {
                    width: parent.width
                    spacing: 12

                    Section {
                        Layout.fillWidth: true
                        Layout.rightMargin: Theme.padding
                        Layout.leftMargin: Theme.padding
                        Layout.topMargin: Theme.padding

                        title: qsTr("Features that will be unavailable:")
                        model: ListModel   {
                            ListElement { text: qsTr("Wallet (Swap, Send, Token data, etc.)") }
                            ListElement { text: qsTr("Market (Token data, prices, and news, etc.)") }
                            ListElement { text: qsTr("Browser (browse web-pages, connect dApps)") }
                            ListElement { text: qsTr("Token-gated communities and admin tools") }
                            ListElement { text: qsTr("Status news, etc.") }
                            ListElement { text: qsTr("Sync with NTP (Network Time Protocol) servers") }
                        }
                    }

                    Section {
                        Layout.fillWidth: true
                        Layout.rightMargin: Theme.padding
                        Layout.leftMargin: Theme.padding
                        Layout.topMargin: Theme.halfPadding
                        Layout.bottomMargin: Theme.padding

                        title: qsTr("You may also experience:")
                        model: ListModel   {
                            ListElement { text: qsTr("Missing or invalid data") }
                            ListElement { text: qsTr("Errors and unexpected behavior") }
                            ListElement { text: qsTr("Missed messages if your device time isn’t synced to network time") }
                        }
                    }
                }
            }

            Paragraph {
                Layout.fillWidth: true
                Layout.fillHeight: true

                textFormat: Text.RichText
                text: qsTr("Only disable third-party services if you're aware of the trade-offs. Re-enable them anytime in Settings. Read more details about third-party services %1.")
                .arg(Utils.getStyledLink("in our article", "#", hoveredLink, Theme.palette.primaryColor1, Theme.palette.primaryColor1, false))
                onLinkActivated: root.openThirdpartyServicesArticleRequested()
                HoverHandler {
                    cursorShape: !!parent.hoveredLink ? Qt.PointingHandCursor : undefined
                }
            }

            InformationTag {
                Layout.fillWidth: true

                backgroundColor: Theme.palette.primaryColor3
                bgBorderColor: Theme.palette.primaryColor2
                bgRadius: 12
                asset.name: "info"
                tagPrimaryLabel.wrapMode: Text.WordWrap
                tagPrimaryLabel.textFormat: Text.RichText
                tagPrimaryLabel.font.pixelSize: Theme.additionalTextSize
                tagPrimaryLabel.text: qsTr("Share feedback or suggest improvements on our %1.")
                .arg(Utils.getStyledLink("Discuss page", "#", tagPrimaryLabel.hoveredLink, Theme.palette.primaryColor1, Theme.palette.primaryColor1, false))
                tagPrimaryLabel.onLinkActivated: root.openDiscussPageRequested()
            }
        }
    }

    footer: StatusDialogFooter {
        dropShadowEnabled: true
        rightButtons: ObjectModel {
            StatusButton {
                type: StatusBaseButton.Type.Primary
                normalColor: Theme.palette.privacyColors.primary
                textColor: Theme.palette.privacyColors.tertiary
                text: {
                    if(root.thirdPartyServicesEnabled) {
                        if(root.isOnboardingFlow) {
                            return qsTr("Disable third-party services")
                        }
                        return qsTr("Disable services and restart the app")
                    }
                    else {
                        if(root.isOnboardingFlow) {
                            return qsTr("Enable third-party services")
                        }
                        return qsTr("Enable services and restart the app")
                    }
                }
                onClicked: {
                    root.toggleThirdpartyServicesEnabledRequested()
                    root.close()
                }
            }
        }
    }

    component Paragraph: StatusBaseText {
        lineHeightMode: Text.FixedHeight
        lineHeight: 22
        wrapMode: Text.Wrap
    }

    component Section: ColumnLayout {
        property alias title: titleItem.text
        property alias model: bodyItem.model
        spacing: Theme.halfPadding

        Paragraph {
            id: titleItem

            Layout.fillWidth: true
            Layout.fillHeight: true
            font.weight: Font.Bold
        }

        Repeater {
            id: bodyItem

            delegate: RowLayout {
                Layout.fillWidth: true
                spacing: Theme.padding
                StatusIcon {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    icon: "info"
                    color: Theme.palette.dangerColor1
                }
                StatusBaseText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: model.text
                }
            }
        }
    }
}
