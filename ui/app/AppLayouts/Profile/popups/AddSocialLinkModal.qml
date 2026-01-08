import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Controls.Validators
import StatusQ.Components
import StatusQ.Popups

import AppLayouts.Profile.controls

StatusStackModal {
    id: root

    property var containsSocialLink: function (text, url) {return false}
    signal addLinkRequested(string linkText, string linkUrl, int linkType, string linkIcon)

    implicitWidth: 480 // design
    implicitHeight: 512 // design
    padding: currentIndex === 0 ? 0 : Theme.padding
    fillHeightOnBottomSheet: true

    headerSettings.title: currentIndex === 0 ? qsTr("Add a link") :
                                               qsTr("Add %1 link").arg(ProfileUtils.linkTypeToText(d.selectedLinkType) || qsTr("custom"))
    rightButtons: [finishButton]
    finishButton: StatusButton {
        text: qsTr("Add")
        objectName: "addButton"
        enabled: linkTarget.valid && (!customTitle.visible || customTitle.valid)
        onClicked: {
            root.addLinkRequested(d.selectedLinkTypeText || customTitle.text, // text for custom link, otherwise the link typeId
                                  ProfileUtils.addSocialLinkPrefix(linkTarget.text, d.selectedLinkType),
                                  d.selectedLinkType, d.selectedIcon)
            root.close()
        }
    }
    showFooter: currentIndex > 0

    onClosed: destroy()

    QtObject {
        id: d

        property int selectedLinkIndex: -1
        readonly property int selectedLinkType: d.selectedLinkIndex !== -1 ? staticLinkTypesModel.get(d.selectedLinkIndex).type : 0
        readonly property string selectedLinkTypeText: d.selectedLinkIndex !== -1 ? staticLinkTypesModel.get(d.selectedLinkIndex).text : ""
        readonly property string selectedIcon: d.selectedLinkIndex !== -1 ? staticLinkTypesModel.get(d.selectedLinkIndex).icon : ""

        readonly property var staticLinkTypesModel: ListModel {
            readonly property var data: [
                { type: Constants.socialLinkType.twitter, icon: "xtwitter", text: "__twitter" },
                { type: Constants.socialLinkType.personalSite, icon: "language", text: "__personal_site" },
                { type: Constants.socialLinkType.github, icon: "github", text: "__github" },
                { type: Constants.socialLinkType.youtube, icon: "youtube", text: "__youtube" },
                { type: Constants.socialLinkType.discord, icon: "discord", text: "__discord" },
                { type: Constants.socialLinkType.telegram, icon: "telegram", text: "__telegram" },
                { type: Constants.socialLinkType.custom, icon: "link", text: "" }
            ]
            Component.onCompleted: append(data)
        }
    }

    onCurrentIndexChanged: {
        //StatusAnimatedStack doesn't handle well items' visibility,
        //keeping this solution for now until #8024 is fixed
        if (currentIndex === 1) {
            customTitle.input.edit.clear()
            linkTarget.input.edit.clear()
            if (d.selectedLinkType === Constants.socialLinkType.custom)
                customTitle.input.edit.forceActiveFocus()
            else
                linkTarget.input.edit.forceActiveFocus()
        }
    }

    stackItems: [
        StatusListView {
            width: root.availableWidth
            height: contentHeight
            model: d.staticLinkTypesModel
            delegate: StatusListItem {
                width: ListView.view.width
                title: ProfileUtils.linkTypeToText(model.type) || qsTr("Custom link")
                asset.name: model.icon
                asset.color: ProfileUtils.linkTypeColor(model.type, root.Theme.palette)
                asset.bgColor: ProfileUtils.linkTypeBgColor(model.type, root.Theme.palette)
                onClicked: {
                    customTitle.reset()
                    linkTarget.reset()
                    d.selectedLinkIndex = index
                    root.currentIndex++
                }
                components: [
                    StatusIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "next"
                        color: Theme.palette.baseColor1
                    }
                ]
            }
        },
        ColumnLayout {
            width: root.availableWidth
            spacing: Theme.halfPadding

            StaticSocialLinkInput {
                id: customTitle
                Layout.fillWidth: true
                visible: d.selectedLinkType === Constants.socialLinkType.custom
                placeholderText: ""
                label: qsTr("Title")
                linkType: Constants.socialLinkType.custom
                icon: "language"
                charLimit: Constants.maxSocialLinkTextLength
                input.tabNavItem: linkTarget.input.edit
                validators: [
                    StatusValidator {
                        name: "text-validation"
                        validate: (value) => {
                                      return value.trim() !== ""
                                  }
                        errorMessage: qsTr("Invalid title")
                    },
                    StatusValidator {
                        name: "check-social-link-existence"
                        validate: (value) => {
                                      return !root.containsSocialLink(value,
                                                                      ProfileUtils.addSocialLinkPrefix(linkTarget.text, d.selectedLinkType))
                                  }
                        errorMessage: qsTr("Title and link combination already added")
                    }
                ]

                onValidChanged: {linkTarget.validate(true)}
                onTextChanged: {linkTarget.validate(true)}
            }

            StaticSocialLinkInput {
                id: linkTarget
                Layout.fillWidth: true
                Layout.topMargin: customTitle.visible ? Theme.padding : 0
                placeholderText: ""
                label: {
                    if (linkType === Constants.socialLinkType.custom)
                        return qsTr("Link")
                    if (linkType === Constants.socialLinkType.personalSite)
                        return qsTr("URL")
                    return qsTr("Username")
                }
                linkType: d.selectedLinkType
                icon: d.selectedIcon
                input.tabNavItem: customTitle.input.edit

                validators: [
                    StatusValidator {
                        name: "link-validation"
                        validate: (value) => {
                                      return value.trim() !== "" && Utils.validLink(ProfileUtils.addSocialLinkPrefix(value, d.selectedLinkType))
                                  }
                        errorMessage: qsTr("Invalid %1").arg(ProfileUtils.linkTypeToDescription(linkTarget.linkType).toLowerCase() || qsTr("link"))
                    },
                    StatusValidator {
                        name: "check-social-link-existence"
                        validate: (value) => {
                                      return !root.containsSocialLink(d.selectedLinkTypeText || customTitle.text,
                                                                      ProfileUtils.addSocialLinkPrefix(value, d.selectedLinkType))
                                  }
                        errorMessage: {
                            if (d.selectedLinkType === Constants.socialLinkType.custom)
                                return qsTr("Title and link combination already added")
                            if (d.selectedLinkType === Constants.socialLinkType.personalSite)
                                return qsTr("URL already added")
                            return qsTr("Username already added")
                        }
                    }
                ]

                onValidChanged: {customTitle.validate(true)}
                onTextChanged: {customTitle.validate(true)}
            }
        }
    ]
}
