import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Components
import StatusQ.Controls

import shared.popups.keycard_new.helpers 1.0
import shared.status

import utils

OnboardingPage {
    id: root

    required property string keycardState
    required property string keycardUid
    required property string keyUid
    required property bool keycardStatusAvailable
    required property int remainingPinAttempts
    required property int remainingPukAttempts
    required property int availableSlots
    required property string cardMetadataName
    required property string cardMetadataWalletAccountsJson

    required property var loginAccountsModel

    signal loginWithThisKeycardRequested()
    signal importNewKeyPairAndCreateProfileRequested()
    signal importFromRecoveryPhraseRequested()
    signal unblockWithRecoveryPhraseRequested()
    signal unblockWithPukRequested()
    signal factoryResetRequested()
    signal goBackToLoginRequested()

    readonly property bool isPortrait: root.width < root.height && root.width <= root.implicitWidth

    title: stateInfo.detailsTitle

    KeycardStateInfo {
        id: stateInfo

        keycardState: root.keycardState
        keycardUid: root.keycardUid
        keyUid: root.keyUid
        keycardStatusAvailable: root.keycardStatusAvailable
        remainingPinAttempts: root.remainingPinAttempts
        remainingPukAttempts: root.remainingPukAttempts
        availableSlots: root.availableSlots
        cardMetadataWalletAccountsJson: root.cardMetadataWalletAccountsJson

        readonly property var matchedProfile: stateInfo.hasKeyPair && root.loginAccountsModel
                                              ? StatusQUtils.ModelUtils.getByKey(root.loginAccountsModel, "keyUid", root.keyUid)
                                              : null
        readonly property bool profileAlreadyExists: !!matchedProfile

        readonly property string detailsTitle: {
            if (stateInfo.noKnownAndNoAvailablePairingSlots)
                return qsTr("No free pairing slots")
            if (stateInfo.isEmpty)
                return qsTr("Keycard is empty")
            if (stateInfo.isBlockedPIN || stateInfo.isBlockedPUK)
                return qsTr("Keycard is blocked")
            if (stateInfo.onlyPinSet)
                return qsTr("Keycard stores only PIN")
            if (profileAlreadyExists)
                return qsTr("Profile already exists")
            if (stateInfo.hasKeyPair)
                return qsTr("Keycard stores key pair")
            return qsTr("Keycard")
        }

        readonly property string nameAndUidLine: {
            let line = ""
            if (root.cardMetadataName)
                line = root.cardMetadataName
            if (root.keycardUid) {
                if (line)
                    line += qsTr(", ")
                line += qsTr("UID: %1").arg(root.keycardUid)
            }
            return line
        }

        readonly property string infoMessage: {
            if (stateInfo.noKnownAndNoAvailablePairingSlots)
                return qsTr("You can’t operate with Keycard content right now, because Keycard has no free pairing slots. But you can use it with previously paired installations.")
            if (profileAlreadyExists)
                return qsTr("Profile for key pair stored on Keycard already added to this device.")
            if (stateInfo.hasKeyPair && stateInfo.cardMetadataWalletAccounts.length > 0)
                return qsTr("Keycard stores information about your accounts")
            return ""
        }
    }

    contentItem: GridLayout {
        rows: root.isPortrait ? 2 : 1
        columns: root.isPortrait ? 1 : 2
        uniformCellWidths: !root.isPortrait

        rowSpacing: Theme.bigPadding
        columnSpacing: Theme.bigPadding

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 280
            Layout.preferredHeight: 280
            Layout.minimumWidth: 100
            Layout.minimumHeight: 100

            StatusImage {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height)
                height: width
                fillMode: Image.PreserveAspectFit
                source: Assets.png("keycard/keycards")
                mipmap: true
            }
        }

        StatusScrollView {
            id: contentScrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            contentWidth: availableWidth

            ColumnLayout {
                width: contentScrollView.availableWidth
                spacing: Theme.padding

                StatusBaseText {
                    Layout.fillWidth: true
                    text: stateInfo.detailsTitle
                    font.pixelSize: Theme.fontSize(22)
                    font.bold: true
                    wrapMode: Text.WordWrap
                }

                StatusBaseText {
                    Layout.fillWidth: true
                    visible: !!text
                    text: stateInfo.nameAndUidLine
                    color: Theme.palette.baseColor1
                    wrapMode: Text.WordWrap
                }

                StatusBaseText {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.padding
                    visible: !!text
                    text: stateInfo.infoMessage
                    color: Theme.palette.baseColor1
                    wrapMode: Text.WordWrap
                }

                KeyPairItem {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.padding
                    visible: stateInfo.hasKeyPair
                             && stateInfo.knownCardMetadata

                    isKnownKeyPair: false

                    userProfileKeyUid: ""
                    userProfileColor: stateInfo.matchedProfile
                                      ? Utils.colorForColorId(Theme.palette, stateInfo.matchedProfile.colorId)
                                      : ""

                    keyPairKeyUid: root.keyUid
                    keyPairMigratedToColdWallet: true
                    keyPairName: stateInfo.matchedProfile
                                 ? stateInfo.matchedProfile.username
                                 : ""
                    keyPairIcon: ""
                    keyPairImage: stateInfo.matchedProfile
                                  ? stateInfo.matchedProfile.thumbnailImage
                                  : ""
                    keyPairCardLocked: false
                    keyPairLocation: ""
                    keyPairLocationColor: ""
                    keyPairAccounts: stateInfo.cardMetadataWalletAccounts
                    areTestNetworksEnabled: false
                }

                StatusSectionHeadline {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.padding
                    text: qsTr("What you can do:")
                }

                StatusListItem {
                    Layout.fillWidth: true
                    visible: stateInfo.isEmpty
                             || stateInfo.onlyPinSet
                    title: qsTr("Import a new key pair to Keycard and create new profile")
                    subTitle: qsTr("Keycard will be required for signing and logging in to Status")
                    components: [
                        StatusIcon {
                            icon: "next"
                            color: Theme.palette.baseColor1
                        }
                    ]
                    onClicked: root.importNewKeyPairAndCreateProfileRequested()
                }

                StatusListItem {
                    Layout.fillWidth: true
                    visible: stateInfo.isEmpty
                             || stateInfo.onlyPinSet
                    title: qsTr("Import a key pair from recovery phrase")
                    subTitle: qsTr("You’ll create a new profile or login if key pair already associated with existing Status profile. Keycard will be required for signing and logging in to Status")
                    components: [
                        StatusIcon {
                            icon: "next"
                            color: Theme.palette.baseColor1
                        }
                    ]
                    onClicked: root.importFromRecoveryPhraseRequested()
                }

                StatusListItem {
                    Layout.fillWidth: true
                    visible: stateInfo.isBlockedPIN
                             || stateInfo.isBlockedPUK
                    title: qsTr("Unblock with recovery phrase")
                    subTitle: qsTr("Requires providing the recovery phrase for the key pair stored on Keycard")
                    components: [
                        StatusIcon {
                            icon: "next"
                            color: Theme.palette.baseColor1
                        }
                    ]
                    onClicked: root.unblockWithRecoveryPhraseRequested()
                }

                StatusListItem {
                    Layout.fillWidth: true
                    visible: stateInfo.isBlockedPIN
                             && !stateInfo.isBlockedPUK
                    title: qsTr("Unblock with PUK")
                    subTitle: qsTr("If you set your PUK earlier for this Keycard")
                    components: [
                        StatusIcon {
                            icon: "next"
                            color: Theme.palette.baseColor1
                        }
                    ]
                    onClicked: root.unblockWithPukRequested()
                }

                StatusListItem {
                    Layout.fillWidth: true
                    visible: stateInfo.hasKeyPair
                             && !stateInfo.isBlockedPIN
                             && !stateInfo.isBlockedPUK
                             && !stateInfo.profileAlreadyExists
                             && !stateInfo.noKnownAndNoAvailablePairingSlots
                    title: qsTr("Login with this Keycard")
                    subTitle: qsTr("Keycard will be required for signing and logging in to Status")
                    components: [
                        StatusIcon {
                            icon: "next"
                            color: Theme.palette.baseColor1
                        }
                    ]
                    onClicked: root.loginWithThisKeycardRequested()
                }

                StatusListItem {
                    Layout.fillWidth: true
                    visible: stateInfo.profileAlreadyExists
                             && !stateInfo.isBlockedPIN
                             && !stateInfo.isBlockedPUK
                    title: qsTr("Go back to login screen")
                    subTitle: qsTr("You can login with password and move your profile to Keycard, from the settings/Keycard section")
                    components: [
                        StatusIcon {
                            icon: "next"
                            color: Theme.palette.baseColor1
                        }
                    ]
                    onClicked: root.goBackToLoginRequested()
                }

                StatusListItem {
                    Layout.fillWidth: true
                    visible: stateInfo.hasKeyPair
                             || stateInfo.onlyPinSet
                             || stateInfo.noKnownAndNoAvailablePairingSlots
                    title: qsTr("Factory reset")
                    subTitle: qsTr("Remove everything from Keycard")
                    components: [
                        StatusIcon {
                            icon: "next"
                            color: Theme.palette.baseColor1
                        }
                    ]
                    onClicked: root.factoryResetRequested()
                }
            }
        }
    }
}
