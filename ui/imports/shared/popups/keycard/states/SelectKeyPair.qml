import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Components
import StatusQ.Controls

import utils
import shared.status

import SortFilterProxyModel

import "../helpers"

Control {
    id: root

    property var sharedKeycardModule

    signal keyPairSelected()

    QtObject {
        id: d
        readonly property int profilePairTypeValue: Constants.keycard.keyPairType.profile
    }

    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding
    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding

    contentItem: ColumnLayout {
        spacing: Theme.padding
        clip: true

        ButtonGroup {
            id: keyPairsButtonGroup
        }

        TitleText {
            id: title
            Layout.fillWidth: true
            text: qsTr("Select a key pair")
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        StatusBaseText {
            id: subTitle
            Layout.fillWidth: true
            text: qsTr("Select which key pair you’d like to move to this Keycard")
            color: Theme.palette.baseColor1
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.halfPadding
        }

        StatusBaseText {
            visible: !userProfile.isKeycardUser
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            Layout.alignment: Qt.AlignLeft
            text: qsTr("Profile key pair")
            color: Theme.palette.baseColor1
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignLeft
        }

        KeyPairList {
            visible: !userProfile.isKeycardUser
            Layout.fillWidth: true

            modelFilters: ExpressionFilter {
                expression: model.keyPair.pairType === d.profilePairTypeValue
            }
            keyPairModel: root.sharedKeycardModule.keyPairModel
            buttonGroup: keyPairsButtonGroup

            onKeyPairSelected: {
                root.sharedKeycardModule.setSelectedKeyPair(keyUid)
                root.keyPairSelected()
            }
        }

        StatusBaseText {
            visible: userProfile.isKeycardUser && root.sharedKeycardModule.keyPairModel.count > 0 ||
                     !userProfile.isKeycardUser && root.sharedKeycardModule.keyPairModel.count > 1
            Layout.fillWidth: true
            text: qsTr("Other key pairs")
            color: Theme.palette.baseColor1
            wrapMode: Text.WordWrap
        }

        KeyPairList {
            visible: userProfile.isKeycardUser && root.sharedKeycardModule.keyPairModel.count > 0 ||
                     !userProfile.isKeycardUser && root.sharedKeycardModule.keyPairModel.count > 1
            Layout.fillWidth: true

            modelFilters: ExpressionFilter {
                expression: model.keyPair.pairType === d.profilePairTypeValue
                inverted: true
            }
            keyPairModel: root.sharedKeycardModule.keyPairModel
            buttonGroup: keyPairsButtonGroup

            onKeyPairSelected: {
                root.sharedKeycardModule.setSelectedKeyPair(keyUid)
                root.keyPairSelected()
            }
        }

        Control {
            Layout.fillWidth: true
            Layout.topMargin: Theme.padding
            padding: Theme.padding
            background: Rectangle {
                radius: Theme.radius
                color: Theme.palette.warningColor3
                border.width: 1
                border.color: Theme.palette.warningColor2
            }
            contentItem: StatusBaseText {
                id: noKeyPairsText
                text: qsTr("If a paired device (like a tablet without NFC) can’t use a Keycard, unpair it before migrating your Status profile. Otherwise, Status will stop working on that device.")
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                color: Theme.palette.warningColor1
            }
        }
        Item {
            Layout.fillHeight: true
        }
    }
}
