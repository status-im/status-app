import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups.Dialog

import utils
import shared
import shared.status

SettingsContentBase {
    id: root

    property bool isProduction
    property string currentVersion
    property string gitCommit
    property string statusGoVersion
    property string qtRuntimeVersion

    signal checkForUpdates()
    signal openLink(string url)

    // TODO when we re-implement check for updates, put isProduction back
    titleRowComponentLoader.active: false //root.isProduction
    titleRowComponentLoader.sourceComponent: StatusButton {
        size: StatusBaseButton.Size.Small
        text: qsTr("Check for updates")
        onClicked: root.checkForUpdates()
    }

    component LinkItem: StatusListItem {
        Layout.fillWidth: true
        components: [
            StatusIcon {
                icon: "external-link"
                color: Theme.palette.directColor1
            }
        ]
    }

    component DocumentItem: StatusListItem {
        Layout.fillWidth: true
        components: [
            StatusIcon {
                icon: "next"
                color: Theme.palette.directColor1
            }
        ]
    }

    ColumnLayout {
        spacing: Constants.settingsSection.itemSpacing
        width: root.contentWidth

        Column {
            Layout.fillWidth: true
            StatusImage {
                id: statusIcon
                width: 80
                height: 80
                source: root.isProduction ? Assets.png("status-logo-circle") : Assets.png("status-logo-dev-circle")
                anchors.horizontalCenter: parent.horizontalCenter
                mipmap: true
            }

            Item { width: 1; height: 8}

            StatusLinkText {
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: Theme.fontSize(22)
                font.bold: true
                normalColor: Theme.palette.directColor1
                text: root.currentVersion
                onClicked: {
                    const link = root.isProduction ? "https://github.com/status-im/status-app/releases/tag/%1".arg(root.currentVersion) :
                                                     "https://github.com/status-im/status-app/commit/%1".arg(root.gitCommit)

                    root.openLink(link)
                }
            }

            StatusBaseText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Current Version")
            }

            Item { width: 1; height: 17}

            StatusLinkText {
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: Theme.secondaryAdditionalTextSize
                font.bold: true
                normalColor: Theme.palette.directColor1
                text: root.statusGoVersion.replace(/^v/, '')
                onClicked: root.openLink("https://github.com/status-im/status-go/tree/%1".arg(root.statusGoVersion))
            }

            StatusBaseText {
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: Theme.additionalTextSize
                text: qsTr("Status Go Version")
            }

            Item { width: 1; height: 17}

            StatusLinkText {
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: Theme.secondaryAdditionalTextSize
                font.bold: true
                normalColor: Theme.palette.directColor1
                text: root.qtRuntimeVersion
                onClicked: root.openLink("https://github.com/qt/qtreleasenotes/blob/dev/qt/%1/release-note.md".arg(text))
            }

            StatusBaseText {
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: Theme.additionalTextSize
                text: qsTr("Qt Version")
            }

            Item { width: 1; height: 17}

            StatusButton {
                anchors.horizontalCenter: parent.horizontalCenter
                size: StatusBaseButton.Size.Small
                icon.name: "info"
                text: qsTr("Release Notes")
                visible: root.isProduction
                onClicked: {
                    const link = root.isProduction ? "https://github.com/status-im/status-app/releases/tag/%1".arg(root.currentVersion) :
                                                     "https://github.com/status-im/status-app/commit/%1".arg(root.gitCommit)

                    root.openLink(link)
                }
            }
        } // Column

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.padding

            LinkItem {
                title: qsTr("Status Manifesto")
                Layout.fillWidth: true
                onClicked: root.openLink("https://status.app/manifesto")
            }

            LinkItem {
                title: qsTr("Status Help")
                Layout.fillWidth: true
                onClicked: root.openLink(Constants.statusHelpLinkPrefix)
            }

            StatusDialogDivider {
                Layout.fillWidth: true
            }

            StatusBaseText {
                Layout.fillWidth: true
                Layout.topMargin: Theme.padding
                Layout.leftMargin: Theme.padding
                text: qsTr("Status App's GitHub Repositories")
                color: Theme.palette.secondaryText
            }

            LinkItem {
                title: qsTr("status-app")
                onClicked: root.openLink("https://github.com/status-im/status-app")
            }

            LinkItem {
                title: qsTr("status-go")
                onClicked: root.openLink("https://github.com/status-im/status-go")
            }

            LinkItem {
                title: qsTr("StatusQ")
                onClicked: root.openLink("https://github.com/status-im/status-app/tree/master/ui/StatusQ")
            }

            LinkItem {
                title: qsTr("logos-delivery-go")
                onClicked: root.openLink("https://github.com/logos-messaging/logos-delivery-go")
            }

            StatusDialogDivider {
                Layout.fillWidth: true
            }

            StatusBaseText {
                Layout.fillWidth: true
                Layout.topMargin: Theme.padding
                Layout.leftMargin: Theme.padding
                text: qsTr("Legal & Privacy Documents")
                color: Theme.palette.secondaryText
            }

            DocumentItem {
                title: qsTr("Terms of Use")
                onClicked: Global.changeAppSectionBySectionType(Constants.appSection.profile,
                                                                Constants.settingsSubsection.about_terms)
            }

            DocumentItem {
                title: qsTr("Privacy Policy")
                onClicked: Global.changeAppSectionBySectionType(Constants.appSection.profile,
                                                                Constants.settingsSubsection.about_privacy)
            }

            LinkItem {
                title: qsTr("Software License")
                onClicked: root.openLink("https://github.com/status-im/status-app/blob/master/LICENSE.md")
            }
        }
    }
}
