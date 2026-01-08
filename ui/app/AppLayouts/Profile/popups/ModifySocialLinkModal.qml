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

StatusDialog {
    id: root

    property var containsSocialLink: function (text, url) {return false}
    property int linkType: -1
    property string icon

    property int index
    property string linkText
    property string linkUrl

    signal updateLinkRequested(string index, string linkText, string linkUrl)
    signal removeLinkRequested(string index)

    implicitWidth: 480 // design
    fillHeightOnBottomSheet: true

    title: ProfileUtils.linkTypeToText(linkType) ? qsTr("Edit %1 link").arg(ProfileUtils.linkTypeToText(linkType)) : qsTr("Edit custom Link")

    footer: StatusDialogFooter {
        leftButtons: ObjectModel {
            StatusButton {
                type: StatusButton.Danger
                text: qsTr("Delete")
                onClicked: {
                    root.removeLinkRequested(root.index)
                    root.close()
                }
            }
        }
        rightButtons: ObjectModel {
            StatusButton {
                text: qsTr("Update")
                enabled: linkTarget.valid && (!customTitle.visible || customTitle.valid)
                onClicked: {
                    root.updateLinkRequested(root.index, customTitle.text, ProfileUtils.addSocialLinkPrefix(linkTarget.text, root.linkType))
                    root.close()
                }
            }
        }
    }

    onAboutToShow: {
        if (linkType === Constants.socialLinkType.custom)
            customTitle.input.edit.forceActiveFocus()
        else
            linkTarget.input.edit.forceActiveFocus()
    }

    onClosed: destroy()

    contentItem: ColumnLayout {
        width: root.availableWidth
        spacing: Theme.halfPadding

        StaticSocialLinkInput {
            id: customTitle
            Layout.fillWidth: true
            visible: root.linkType === Constants.socialLinkType.custom
            placeholderText: ""
            label: qsTr("Change title")
            linkType: Constants.socialLinkType.custom
            icon: "language"
            text: root.linkText
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
                                                                  ProfileUtils.addSocialLinkPrefix(linkTarget.text, root.linkType))
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
            label: ProfileUtils.linkTypeToDescription(linkType) || qsTr("Edit your link")
            linkType: root.linkType
            icon: root.icon
            text: root.linkUrl
            input.tabNavItem: customTitle.input.edit

            validators: [
                StatusValidator {
                    name: "link-validation"
                    validate: (value) => {
                                  return value.trim() !== "" && Utils.validLink(ProfileUtils.addSocialLinkPrefix(value, root.linkType))
                              }
                    errorMessage: qsTr("Invalid %1").arg(ProfileUtils.linkTypeToDescription(linkTarget.linkType).toLowerCase() || qsTr("link"))
                },
                StatusValidator {
                    name: "check-social-link-existence"
                    validate: (value) => {
                                  return !root.containsSocialLink(customTitle.text,
                                                                  ProfileUtils.addSocialLinkPrefix(value, root.linkType))
                              }
                    errorMessage: {
                        if (root.linkType === Constants.socialLinkType.custom)
                            return qsTr("Title and link combination already added")
                        if (root.linkType === Constants.socialLinkType.personalSite)
                            return qsTr("URL already added")
                        return qsTr("Username already added")
                    }
                }
            ]

            onValidChanged: {customTitle.validate(true)}
            onTextChanged: {customTitle.validate(true)}
        }
    }
}
