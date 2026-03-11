import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

import shared.controls

SettingsContentBase {
    id: root

    property bool isStatusNewsViaRSSEnabled
    required property bool thirdpartyServicesEnabled
    required property bool privacyModeFeatureEnabled
    required property var whitelistedDomainsModel
    required property string privacySectionTitle

    property string backButtonText

    signal setNewsRSSEnabledRequested(bool isStatusNewsViaRSSEnabled)
    signal openThirdpartyServicesInfoPopupRequested()
    signal openDiscussPageRequested()
    signal removeWhitelistedDomain(int index)

    function resetStack() {
            stackContainer.currentIndex = 0
    }

    StackLayout {
        id: stackContainer

        // Main Security & Privacy Page
        ColumnLayout {
            StatusListItem {
                Layout.preferredWidth: root.contentWidth
                title: qsTr("Receive Status News via RSS")
                subTitle: qsTr("Your IP address will be exposed to https://status.app")
                components: [
                    StatusSwitch {
                        id: statusNewsSwitch
                        checked: root.isStatusNewsViaRSSEnabled
                        onToggled: root.setNewsRSSEnabledRequested(statusNewsSwitch.checked)
                    }
                ]
                onClicked: root.setNewsRSSEnabledRequested(!statusNewsSwitch.checked)
                enabled: root.thirdpartyServicesEnabled
            }

            // Divider
            Rectangle {
                Layout.preferredWidth: root.contentWidth
                Layout.preferredHeight: 1
                color: Theme.palette.baseColor2
            }

            StatusListItem {
                Layout.preferredWidth: root.contentWidth
                title: qsTr("Third-party services")
                subTitle: qsTr("Enable/disable all third-party services")
                components: [
                    StatusSwitch {
                        checkable: false
                        checked: root.thirdpartyServicesEnabled
                        onClicked: root.openThirdpartyServicesInfoPopupRequested()
                    }
                ]
                onClicked: root.openThirdpartyServicesInfoPopupRequested()
                visible: root.privacyModeFeatureEnabled
            }

            InformationTag {
                id: infoTag

                Layout.preferredWidth: root.contentWidth
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignHCenter

                leftInset: Theme.padding
                rightInset: Theme.padding
                leftPadding: horizontalPadding + Theme.padding
                rightPadding: horizontalPadding + Theme.padding

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
                visible: root.privacyModeFeatureEnabled
            }

            // Divider
            Rectangle {
                Layout.preferredWidth: root.contentWidth
                Layout.preferredHeight: 1
                color: Theme.palette.baseColor2
            }

            // Trusted Sites
            StatusListItem {
                Layout.preferredWidth: root.contentWidth
                title: qsTr("Trusted sites")
                subTitle: qsTr("Manage trusted sites. Their links open without confirmation.")
                components: [
                    StatusIcon {
                        icon: "next"
                        color: Theme.palette.baseColor1
                    }
                ]
                onClicked: stackContainer.currentIndex = 1
            }

            // Divider
            Rectangle {
                Layout.preferredWidth: root.contentWidth
                Layout.preferredHeight: 1
                color: Theme.palette.baseColor2
            }
        }

        // Whitelisted Domains Page
        WhitelistedDomainsView {
            Layout.fillWidth: true
            whitelistedDomainsModel: root.whitelistedDomainsModel
            onRemoveWhitelistedDomain: index => root.removeWhitelistedDomain(index)
        }

    }

    Component {
        id: privacyPolicyButton
        StatusButton {
            text: qsTr("Privacy policy")
            onClicked: Global.privacyPolicyRequested()
        }
    }

    states: [
        State {
            name: "mainView"
            when: stackContainer.currentIndex === 0
            PropertyChanges {
                target: root
                backButtonText: ""
            }
            PropertyChanges {
                target: titleRowComponentLoader
                sourceComponent: privacyPolicyButton
            }
            PropertyChanges {
                target: root
                sectionTitle: root.privacySectionTitle
            }
        },
        State {
            name: "whitelistedDomainsView"
            when: stackContainer.currentIndex === 1
            PropertyChanges {
                target: root
                backButtonText: root.privacySectionTitle
            }
            PropertyChanges {
                target: titleRowComponentLoader
                sourceComponent: undefined
            }
            PropertyChanges {
                target: root
                sectionTitle: ""
            }
        }
    ]
}
