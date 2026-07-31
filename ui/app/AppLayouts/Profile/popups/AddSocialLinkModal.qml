import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import utils

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Controls.Validators
import StatusQ.Components
import StatusQ.Popups.Dialog

import AppLayouts.Profile.controls

StatusAdaptiveDialog {
    id: root

    property var containsSocialLink: function (text, url) {return false}
    property int currentIndex: 0

    signal addLinkRequested(string linkText, string linkUrl, int linkType, string linkIcon)

    title: currentIndex === 0 ? qsTr("Add a link") :
                                qsTr("Add %1 link").arg(ProfileUtils.linkTypeToText(d.selectedLinkType) || qsTr("custom"))
    footerLeftButtons: currentIndex > 0 ? footerLeftButtonsModel : null
    footerRightButtons: currentIndex > 0 ? footerRightButtonsModel : null
    destroyOnClose: true

    contentComponent: Component {
        Loader {
            sourceComponent: root.currentIndex === 0 ? linkTypeStepComponent : linkDetailsStepComponent
            implicitHeight: item ? item.implicitHeight : 0
        }
    }

    ObjectModel {
        id: footerLeftButtonsModel

        StatusBackButton {
            onClicked: root.currentIndex = 0
            Layout.minimumWidth: implicitWidth
        }
    }

    ObjectModel {
        id: footerRightButtonsModel

        StatusButton {
            text: qsTr("Add")
            objectName: "addButton"
            enabled: d.detailsValid
            onClicked: {
                root.addLinkRequested(d.selectedLinkTypeText || d.customTitleText, // text for custom link, otherwise the link typeId
                                      ProfileUtils.addSocialLinkPrefix(d.linkTargetText, d.selectedLinkType),
                                      d.selectedLinkType, d.selectedIcon)
                root.close()
            }
        }
    }

    QtObject {
        id: d

        property int selectedLinkIndex: -1
        property bool detailsValid: false
        property string customTitleText
        property string linkTargetText

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
        d.detailsValid = false
        d.customTitleText = ""
        d.linkTargetText = ""
    }

    Component {
        id: linkTypeStepComponent

        StatusListView {
            width: root.availableWidth
            height: contentHeight
            implicitHeight: contentHeight
            model: d.staticLinkTypesModel
            delegate: StatusListItem {
                width: ListView.view.width
                title: ProfileUtils.linkTypeToText(model.type) || qsTr("Custom link")
                asset.name: model.icon
                asset.color: ProfileUtils.linkTypeColor(model.type, root.Theme.palette)
                asset.bgColor: ProfileUtils.linkTypeBgColor(model.type, root.Theme.palette)
                onClicked: {
                    d.selectedLinkIndex = index
                    root.currentIndex = 1
                }
                components: [
                    StatusIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "next"
                        color: Theme.palette.baseColor1
                    }
                ]
            }
        }
    }

    Component {
        id: linkDetailsStepComponent

        ColumnLayout {
            id: detailsStep

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

                onValidChanged: {
                    linkTarget.validate(true)
                    detailsStep.updateDetailsState()
                }
                onTextChanged: {
                    linkTarget.validate(true)
                    detailsStep.updateDetailsState()
                }
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

                onValidChanged: {
                    customTitle.validate(true)
                    detailsStep.updateDetailsState()
                }
                onTextChanged: {
                    customTitle.validate(true)
                    detailsStep.updateDetailsState()
                }
            }

            function updateDetailsState() {
                d.customTitleText = customTitle.text
                d.linkTargetText = linkTarget.text
                d.detailsValid = linkTarget.valid && (!customTitle.visible || customTitle.valid)
            }

            Component.onCompleted: {
                customTitle.reset()
                linkTarget.reset()
                detailsStep.updateDetailsState()
                if (d.selectedLinkType === Constants.socialLinkType.custom)
                    customTitle.input.edit.forceActiveFocus()
                else
                    linkTarget.input.edit.forceActiveFocus()
            }
        }
    }
}
