import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components

import AppLayouts.Profile.popups

import utils

StatusListView {
    id: root

    signal saveExemptionsRequested(string itemId, bool muteAllMessages, string personalMentions, string globalMentions, string allMessages)

    delegate: StatusListItem {
        width: ListView.view.width
        title: model.name
        subTitle: {
            if(model.type === Constants.settingsSection.exemptions.community)
                return qsTr("Community")
            if(model.type === Constants.settingsSection.exemptions.oneToOneChat)
                return qsTr("1:1 Chat")
            if(model.type === Constants.settingsSection.exemptions.groupChat)
                return qsTr("Group Chat")
            return ""
        }
        label: {
            if(!model.customized)
                return ""

            let l = ""
            if(model.muteAllMessages)
                l += qsTr("Muted")
            else {
                let nbOfChanges = 0

                if(model.personalMentions !== Constants.settingsSection.notifications.sendAlertsValue)
                {
                    nbOfChanges++
                    let valueText = model.personalMentions === Constants.settingsSection.notifications.turnOffValue?
                            qsTr("Off") :
                            qsTr("Quiet")
                    l = qsTr("Personal @ Mentions %1").arg(valueText)
                }

                if(model.globalMentions !== Constants.settingsSection.notifications.sendAlertsValue)
                {
                    nbOfChanges++
                    let valueText = model.globalMentions === Constants.settingsSection.notifications.turnOffValue?
                            qsTr("Off") :
                            qsTr("Quiet")
                    l = qsTr("Global @ Mentions %1").arg(valueText)
                }

                if(model.otherMessages !== Constants.settingsSection.notifications.turnOffValue)
                {
                    nbOfChanges++
                    let valueText = model.otherMessages === Constants.settingsSection.notifications.sendAlertsValue?
                            qsTr("Alerts") :
                            qsTr("Quiet")
                    l = qsTr("Other Messages %1").arg(valueText)
                }

                if(nbOfChanges > 1)
                    l = qsTr("Multiple Exemptions")
            }

            return l
        }

        asset {
            name: model.image
            isImage: !!model.image && model.image !== ""
            color: model.type === Constants.settingsSection.exemptions.oneToOneChat?
                       Utils.colorForPubkey(root.Theme.palette, model.itemId) :
                       model.color
            charactersLen: model.type === Constants.settingsSection.exemptions.oneToOneChat? 2 : 1
            isLetterIdenticon: !model.image || model.image === ""
            height: 40
            width: 40
        }

        components: [
            StatusFlatButton {
                id: popupBtn
                icon.name: model.customized ? "next" : "add"
                icon.color: model.customized ? Theme.palette.baseColor1 : Theme.palette.primaryColor1
                size: StatusBaseButton.Size.Small
                onClicked: {
                    const props = {
                        name: model.name,
                        type: model.type,
                        itemId: model.itemId,
                        color: model.color,
                        image: model.image,
                        muteAllMessages: model.muteAllMessages,
                        personalMentions: model.personalMentions,
                        globalMentions: model.globalMentions,
                        otherMessages: model.otherMessages
                    }
                    exemptionNotificationsModal.createObject(root, props).open()
                }
            }
        ]
        sensor.cursorShape: Qt.PointingHandCursor
        onClicked: popupBtn.click()
    }

    Component {
        id: exemptionNotificationsModal
        ExemptionNotificationsModal {
            destroyOnClose: true
            onSaveExemptionsRequested: (itemId, muteAllMessages, personalMentions, globalMentions, allMessages) =>
                                       root.saveExemptionsRequested(itemId, muteAllMessages, personalMentions, globalMentions, allMessages)
        }
    }
}
