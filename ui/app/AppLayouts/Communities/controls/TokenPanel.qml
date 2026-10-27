import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components

import shared.controls

import utils


ColumnLayout {
    id: root

    property int mode: HoldingTypes.Mode.Add
    property alias tokenName: item.name
    property alias tokenShortName: item.shortName
    property alias tokenAmount: item.amount
    property alias tokenImage: item.iconSource
    property alias tokenDecimals: item.decimals
    property alias amountText: amountInput.text
    property alias amount: amountInput.amount
    property alias decimals: amountInput.tokenDecimals
    property alias multiplierIndex: amountInput.multiplierIndex
    property alias tokenCategoryText: tokenLabel.text
    property alias networkLabelText: d.networkLabelText
    property alias addOrUpdateButtonEnabled: addOrUpdateButton.enabled
    property alias allowDecimals: amountInput.allowDecimals
    readonly property bool amountValid: amountInput.valid && !!amountInput.text
    // token data not known yet: placeholder instead of the token, no editing
    property bool loading: false
    property string infoText

    property var networksModel

    signal addClicked
    signal updateClicked
    signal removeClicked

    function setAmount(amount, multiplierIndex = 0) {
        console.assert(typeof amount === "string")
        amountInput.setAmount(amount, multiplierIndex)
    }

    QtObject {
        id: d

        // values from design
        readonly property int defaultHeight: 44
        readonly property int defaultSpacing: 8

        property string networkLabelText: qsTr("Network for airdrop")
    }

    component CustomText: StatusBaseText {
        color: Theme.palette.baseColor1
        font.pixelSize: Theme.tertiaryTextFontSize
        elide: Text.ElideRight

        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: d.defaultSpacing
    }

    spacing: d.defaultSpacing

    CustomText {
        id: tokenLabel

        Layout.topMargin: 2 * d.defaultSpacing
    }

    TokenItem {
        id: item

        Layout.fillWidth: true
        enabled: false
        visible: !root.loading
    }

    LoadingComponent {
        objectName: "tokenLoadingIndicator"

        Layout.fillWidth: true
        Layout.preferredHeight: d.defaultHeight
        radius: 8
        visible: root.loading
    }

    Loader {
        id: networksComboBoxLoader

        active: !!root.networksModel
        visible: active

        Layout.fillWidth: true
        Layout.topMargin: 14
        Layout.bottomMargin: d.defaultSpacing

        sourceComponent: ColumnLayout {
            spacing: 10

            property alias currentAmount: inlineNetworksComboBox.currentAmount
            property alias decimals: inlineNetworksComboBox.decimals
            property alias currentMultiplierIndex:
                inlineNetworksComboBox.currentMultiplierIndex
            property alias currentInfiniteAmount:
                inlineNetworksComboBox.currentInfiniteAmount

            CustomText {
                id: networkLabel

                text: d.networkLabelText

                color: Theme.palette.baseColor1
                font.pixelSize: Theme.tertiaryTextFontSize
                elide: Text.ElideRight
            }

            InlineNetworksComboBox {
                id: inlineNetworksComboBox

                Layout.fillWidth: true

                model: root.networksModel
            }
        }
    }

    AmountInput {
        id: amountInput
        objectName: "amountInput"

        Layout.fillWidth: true
        enabled: !root.loading
        Layout.bottomMargin: (validationError !== "") ? root.spacing * 2 : 0
        customHeight: d.defaultHeight
        allowDecimals: true
        keepHeight: true

        validateMaximumAmount:
            !!networksComboBoxLoader.item &&
            !networksComboBoxLoader.item.currentInfiniteAmount

        maximumAmount: !!networksComboBoxLoader.item
                       ? networksComboBoxLoader.item.currentAmount : "0"
        tokenDecimals: !!networksComboBoxLoader.item
                       ? networksComboBoxLoader.item.decimals : root.tokenDecimals
        multiplierIndex: !!networksComboBoxLoader.item
                         ? networksComboBoxLoader.item.currentMultiplierIndex : 0

        onKeyPressed: function (event) {
            if(!addOrUpdateButton.enabled)
                return

            // additionally accept dot (.) and convert it to the correct decimal point char
            if (event.key === Qt.Key_Period || event.key === Qt.Key_Comma) {
                // Only one decimal point is allowed
                if(amountInput.text.indexOf(amountInput.locale.decimalPoint) === -1)
                  amountInput.textField.insert(amountInput.textField.cursorPosition, amountInput.locale.decimalPoint)
                event.accepted = true
            } else if ((event.key > Qt.Key_9 && event.key <= Qt.Key_BraceRight) || event.key === Qt.Key_Space) {
                event.accepted = true
            } else if(event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                addOrUpdateButton.clicked()
            }
        }
        onVisibleChanged: {
            if(visible)
                forceActiveFocus()
        }
        Component.onCompleted: {
            if(visible)
                forceActiveFocus()
        }
    }

    CustomText {
        text: root.infoText
        visible: !!root.infoText
        wrapMode: Text.Wrap
    }

    StatusButton {
        id: addOrUpdateButton
        objectName: "addOrUpdateButton"

        text: root.mode === HoldingTypes.Mode.Add ? qsTr("Add")
                                                  : qsTr("Update")
        Layout.preferredHeight: d.defaultHeight
        Layout.topMargin: d.defaultSpacing
        Layout.fillWidth: true
        onClicked: root.mode === HoldingTypes.Mode.Add
                   ? root.addClicked() : root.updateClicked()
    }

    StatusFlatButton {
        text: qsTr("Remove")
        Layout.preferredHeight: d.defaultHeight
        Layout.fillWidth: true
        Layout.topMargin: d.defaultSpacing
        visible: root.mode === HoldingTypes.Mode.UpdateOrRemove
        type: StatusBaseButton.Type.Danger

        onClicked: root.removeClicked()
    }
}
