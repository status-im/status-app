import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import utils

CommonContactAdaptiveDialog {
    id: root

    readonly property bool removeIDVerification: d.removeIDVerification
    readonly property bool removeContact: d.removeContact

    title: qsTr("Block user")

    QtObject {
        id: d

        property bool removeIDVerification
        property bool removeContact
    }

    bodyComponent: ColumnLayout {
        spacing: Theme.halfPadding

        StatusBaseText {
            objectName: "youWillNotSeeText"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            lineHeight: 22
            lineHeightMode: Text.FixedHeight
            text: qsTr("You will not see %1’s messages but %1 can still see your messages in mutual group chats and communities. %1 will be unable to message you.").arg(mainDisplayName)
        }

        StatusWarningBox {
            objectName: "blockWarningBox"
            Layout.fillWidth: true
            Layout.topMargin: Theme.halfPadding
            icon: "warning"
            iconColor: Theme.palette.dangerColor1
            bgColor: Theme.palette.dangerColor1
            borderColor: Theme.palette.dangerColor2
            textColor: Theme.palette.directColor1
            textSize: Theme.secondaryTextFontSize
            text: qsTr("Blocking a user purges the database of all messages that you’ve previously received from %1 in all contexts. This can take a moment.").arg(mainDisplayName)
        }

        StatusCheckBox {
            Layout.topMargin: Theme.halfPadding
            objectName: "removeContactCheckbox"
            id: ctrlRemoveContact
            visible: contactDetails.isContact
            checked: visible
            enabled: false
            text: qsTr("Remove contact")
            onCheckedChanged: d.removeContact = checked
            Component.onCompleted: d.removeContact = checked
        }

        StatusCheckBox {
            id: ctrlRemoveIDVerification
            visible: contactDetails.trustStatus === Constants.trustStatus.trusted
            checked: visible
            enabled: false
            text: qsTr("Remove trust mark")
            onCheckedChanged: d.removeIDVerification = checked
            Component.onCompleted: d.removeIDVerification = checked
        }
    }

    footerRightButtons: ObjectModel {
        StatusFlatButton {
            objectName: "cancelButton"
            text: qsTr("Cancel")
            onClicked: root.close()
        }
        StatusButton {
            objectName: "blockButton"
            type: StatusBaseButton.Type.Danger
            text: qsTr("Block")
            onClicked: root.accepted()
        }
    }
}
