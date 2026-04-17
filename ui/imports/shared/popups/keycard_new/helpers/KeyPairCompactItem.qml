import QtQuick
import QtQml.Models
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Components
import StatusQ.Controls

import utils

StatusListItem {
    id: root

    property string userProfilePublicKey

    property ButtonGroup buttonGroup
    property bool usedAsSelectOption: false
    property bool tagClickable: false
    property bool tagDisplayRemoveAccountButton: false
    property bool canBeSelected: true
    property bool checked: false
    property bool displayRadioButtonForSelection: true
    property bool useTransparentItemBackgroundColor: false

    property int keyPairType: Constants.keycard.keyPairType.unknown
    property string keyPairName: ""
    property string keyPairIcon: ""
    property string keyPairImage: ""
    property bool keyPairCardLocked: false
    property var keyPairAccounts

    property bool displayAdditionalInfoForProfileKeypair: true
    property string additionalInfoForProfileKeypair: qsTr("Moving this key pair will require you to use your Keycard to login")

    signal keyPairSelected()
    signal removeAccount(int index, string name)
    signal accountClicked(int index)

    color: {
        if (!root.useTransparentItemBackgroundColor) {
            return root.keyPairCardLocked? Theme.palette.dangerColor3 : Theme.palette.baseColor2
        }

        if (sensor.containsMouse) {
            return Theme.palette.baseColor2
        }

        return StatusColors.transparent
    }
    title: root.keyPairName
    statusListItemTitleAside.textFormat: Text.RichText
    statusListItemTitleAside.visible: !!statusListItemTitleAside.text
    statusListItemTitleAside.text: {
        let t = ""
        if (root.keyPairType === Constants.keycard.keyPairType.profile) {
            t = Utils.getElidedCompressedPk(root.userProfilePublicKey)
        }
        if (root.keyPairCardLocked) {
            let label = qsTr("Keycard Locked")
            t += ` <font color="${Theme.palette.dangerColor1}" size="5">${label}</font>`
        }
        return t
    }

    beneathTagsTitle: root.keyPairType === Constants.keycard.keyPairType.profile && root.displayAdditionalInfoForProfileKeypair?
                          root.additionalInfoForProfileKeypair :
                          !root.canBeSelected?
                              qsTr("Contains %n account(s) with Keycard incompatible derivation paths", "", root.keyPairAccounts.count) :
                              ""
    beneathTagsIcon: !!beneathTagsTitle? "info" : ""

    asset {
        width: root.keyPairIcon? 24 : 40
        height: root.keyPairIcon? 24 : 40
        name: root.keyPairImage? root.keyPairImage
                               : root.keyPairIcon? root.keyPairIcon
                                                 : root.keyPairType === Constants.keycard.keyPairType.profile? "contact"
                                                                                                             : ""
        isImage: !!root.keyPairImage
        color: root.keyPairType === Constants.keycard.keyPairType.profile? Theme.palette.indirectColor2
                                                                          : root.keyPairCardLocked? Theme.palette.dangerColor1
                                                                                                  : Theme.palette.primaryColor1
        letterSize: Math.max(4, asset.width / 2.4)
        charactersLen: 2
        isLetterIdenticon: !root.keyPairImage && !root.keyPairIcon && root.keyPairType !== Constants.keycard.keyPairType.profile
        bgColor: root.keyPairCardLocked? Theme.palette.dangerColor3
                                       : root.keyPairType === Constants.keycard.keyPairType.profile? Utils.colorForPubkey(Theme.palette, root.userProfilePublicKey)
                                                                                                   : Theme.palette.primaryColor3
    }

    tagsModel: root.keyPairAccounts

    tagsDelegate: StatusListItemTag {
        readonly property var acc: model.account !== undefined && model.account !== null
                                   ? model.account
                                   : model

        bgColor: Utils.getColorForId(Theme.palette, acc.colorId ?? "")
        height: Theme.defaultBigPadding
        bgRadius: 6
        tagClickable: root.tagClickable
        closeButtonVisible: root.tagDisplayRemoveAccountButton
        asset {
            emoji: acc.emoji ?? ""
            emojiSize: Emoji.size.verySmall
            isLetterIdenticon: !!(acc.emoji ?? "")
            name: acc.icon ?? ""
            color: Theme.palette.indirectColor1
            width: 16
            height: 16
        }
        title: Utils.appTranslation(acc.name ?? "")
        titleText.color: Theme.palette.indirectColor1
        titleText.font.pixelSize: Theme.tertiaryTextFontSize

        onClicked: {
            root.removeAccount(index, acc.name ?? "")
        }

        onTagClicked: {
            root.accountClicked(index)
        }
    }

    components: root.canBeSelected? d.components : []

    QtObject {
        id: d

        property list<Item> components: [
            StatusRadioButton {
                id: radioButton
                visible: root.usedAsSelectOption && root.displayRadioButtonForSelection
                ButtonGroup.group: root.buttonGroup
                onCheckedChanged: {
                    d.doAction(checked)
                }

                Component.onCompleted: {
                    checked = root.checked
                }
            },
            StatusIcon {
                visible: root.usedAsSelectOption && !root.displayRadioButtonForSelection
                icon: "next"
                color: Theme.palette.baseColor1
                StatusMouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        d.doAction(true)
                    }
                }
            }
        ]

        function doAction(checked){
            if (!root.usedAsSelectOption || !root.canBeSelected)
                return
            if (checked) {
                root.keyPairSelected()
            }
        }
    }

    onClicked: {
        if (!root.usedAsSelectOption || !root.canBeSelected)
            return
        d.doAction(!root.displayRadioButtonForSelection || radioButton.checked)
    }
}
