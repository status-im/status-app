import QtQuick
import QtQuick.Controls

import Storybook

import AppLayouts.Profile.popups

Item {
    id: root

    PopupBackground {
        anchors.fill: parent

        Button {
            anchors.centerIn: parent
            text: "Reopen"
            onClicked: popup.open()
        }

        RenameKeypairPopup {
            id: popup
            anchors.centerIn: parent
            visible: true
            destroyOnClose: false
            keyUid: "seed-key-uid"
            name: "Imported key pair"
            accounts: accountsModel
            accountsModule: accountsModuleStub
        }
    }

    ListModel {
        id: accountsModel
        Component.onCompleted: {
            append({
                account: {
                    name: "Account 1",
                    emoji: "😎",
                    colorId: "purple",
                    icon: ""
                }
            })
        }
    }

    QtObject {
        id: accountsModuleStub
        property var takenNames: ["Taken"]

        function keypairNameExists(name) {
            return takenNames.indexOf(name) !== -1
        }

        function renameKeypair(keyUid, name) {}
    }
}

// category: Popups
// status: good
