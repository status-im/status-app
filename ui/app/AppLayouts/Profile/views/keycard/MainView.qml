import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups
import StatusQ.Popups.Dialog

import utils
import shared.panels
import shared.controls
import shared.status
import shared.popups.keycard.helpers

import "../../stores"

ColumnLayout {
    id: root

    property KeycardStore keycardStore

    signal displayKeycardsForKeypair(string keyUid, string keypairName)

    spacing: Constants.settingsSection.itemSpacing

    QtObject {
        id: d

        readonly property bool noKeycardsSet: root.keycardStore.keycardModule.keycardModel.count === 0
    }

    Image {
        visible: d.noKeycardsSet
        Layout.alignment: Qt.AlignCenter
        Layout.preferredHeight: 240
        Layout.preferredWidth: 350
        fillMode: Image.PreserveAspectFit
        antialiasing: true
        source: Assets.png("keycard/card_insert/insert")
        mipmap: true
        cache: false
    }

    Item {
        visible: d.noKeycardsSet
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.halfPadding
    }

    StyledText {
        visible: d.noKeycardsSet
        Layout.alignment: Qt.AlignCenter
        font.pixelSize: Theme.fontSize(18)
        color: Theme.palette.directColor1
        text: qsTr("Secure your funds. Keep your profile safe.")
    }

    Item {
        visible: d.noKeycardsSet
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.halfPadding
    }

    StatusSectionHeadline {
        visible: !d.noKeycardsSet
        Layout.fillWidth: true
        Layout.leftMargin: Theme.padding
        Layout.rightMargin: Theme.padding
        text: qsTr("Your Keycard(s)")
    }

    StatusListView {
        visible: !d.noKeycardsSet
        Layout.fillWidth: true
        Layout.preferredHeight: 250
        spacing: Theme.padding
        model: root.keycardStore.keycardModule.keycardModel

        delegate: KeycardItem {
            width: ListView.view.width

            keycardName: model.keycard.name
            keycardLocked: model.keycard.locked
            keyPairType: model.keycard.pairType
            keyPairIcon: model.keycard.icon
            keyPairImage: model.keycard.image
            keyPairAccounts: model.keycard.accounts

            onKeycardSelected: {
                root.displayKeycardsForKeypair(model.keycard.keyUid, model.keycard.name)
            }
        }
    }

    StatusListItem {
        Layout.fillWidth: true
        title: d.noKeycardsSet? qsTr("Setup a new Keycard with an existing account")
                              : qsTr("Migrate an existing account from Status Desktop to Keycard")
        objectName: "setupFromExistingKeycardAccount"
        components: [
            StatusIcon {
                icon: "next"
                color: Theme.palette.baseColor1
            }
        ]
        onClicked: {
            root.keycardStore.runSetupKeycardPopup("")
        }
    }

    StatusSectionHeadline {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.padding
        Layout.rightMargin: Theme.padding
        text: qsTr("Create, import or restore a Keycard account")
    }

    StatusListItem {
        Layout.fillWidth: true
        title: qsTr("Create a new Keycard account with a new recovery phrase")
        objectName: "createNewKeycardAccount"
        components: [
            StatusIcon {
                icon: "next"
                color: Theme.palette.baseColor1
            }
        ]
        onClicked: {
            if (root.keycardStore.remainingKeypairCapacity() === 0) {
                Global.openPopup(limitWarningComponent)
                return
            }
            if (root.keycardStore.remainingAccountCapacity() === 0) {
                Global.openPopup(limitWarningComponent, {accountsWarning: true})
                return
            }
            root.keycardStore.runCreateNewKeycardWithNewSeedPhrasePopup()
        }
    }

    StatusListItem {
        Layout.fillWidth: true
        title: qsTr("Import or restore via a recovery phrase")
        objectName: "importRestoreKeycard"
        components: [
            StatusIcon {
                icon: "next"
                color: Theme.palette.baseColor1
            }
        ]
        onClicked: {
            if (root.keycardStore.remainingKeypairCapacity() === 0) {
                Global.openPopup(limitWarningComponent)
                return
            }
            if (root.keycardStore.remainingAccountCapacity() === 0) {
                Global.openPopup(limitWarningComponent, {accountsWarning: true})
                return
            }
            root.keycardStore.runImportOrRestoreViaSeedPhrasePopup()
        }
    }

    StatusListItem {
        Layout.fillWidth: true
        title: qsTr("Import from Keycard to Status Desktop")
        objectName: "importFromKeycard"
        components: [
            StatusIcon {
                icon: "next"
                color: Theme.palette.baseColor1
            }
        ]
        onClicked: {
            if (root.keycardStore.remainingKeypairCapacity() === 0) {
                Global.openPopup(limitWarningComponent)
                return
            }
            if (root.keycardStore.remainingAccountCapacity() === 0) {
                Global.openPopup(limitWarningComponent, {accountsWarning: true})
                return
            }
            root.keycardStore.runImportFromKeycardToAppPopup()
        }
    }

    StatusSectionHeadline {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.padding
        Layout.rightMargin: Theme.padding
        text: qsTr("Other")
    }

    StatusListItem {
        Layout.fillWidth: true
        title: qsTr("Check what’s on a Keycard")
        objectName: "checkWhatsNewKeycard"
        components: [
            StatusIcon {
                icon: "next"
                color: Theme.palette.baseColor1
            }
        ]
        onClicked: {
            root.keycardStore.runDisplayKeycardContentPopup()
        }
    }

    StatusListItem {
        Layout.fillWidth: true
        title: qsTr("Factory reset a Keycard")
        objectName: "factoryResetKeycard"
        components: [
            StatusIcon {
                icon: "next"
                color: Theme.palette.baseColor1
            }
        ]
        onClicked: {
            root.keycardStore.runFactoryResetPopup()
        }
    }

    Component {
        id: limitWarningComponent

        StatusDialog {
            id: dialog

            property bool accountsWarning: false

            title: dialog.accountsWarning? Constants.walletConstants.maxNumberOfAccountsTitle : Constants.walletConstants.maxNumberOfKeypairsTitle

            StatusBaseText {
                anchors.fill: parent
                color: Theme.palette.directColor1
                text: dialog.accountsWarning? Constants.walletConstants.maxNumberOfAccountsContent : Constants.walletConstants.maxNumberOfKeypairsContent
            }

            standardButtons: Dialog.Ok
        }
    }
}
