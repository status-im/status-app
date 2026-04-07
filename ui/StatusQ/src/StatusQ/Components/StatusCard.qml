pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Controls.Validators

/*!
   \qmltype StatusCard
   \inherits Rectangle
   \inqmlmodule StatusQ.Components
   \since StatusQ.Components 0.1
   \brief This component represents a StatusCard as defined in design under https://www.figma.com/file/FkFClTCYKf83RJWoifWgoX/Wallet-v2?node-id=3161%3A171040

   There is an advanced mode available where a StatusInput is provided for the user to be able to change values.

   Example of how the component looks like:
   \image status_card.png

   Example of how to use it:
   \qml
        StatusCard {
            id: card
            primaryText: "Mainnet"
            secondaryText: "75"
            tertiaryText: "BALANCE: " + 250
            cardIconName: "status"
            advancedMode: false
            disableText: "Disable"
            enableText: "enable"
            maxAdvancedValue: 100
        }
   \endqml
   For a list of components available see StatusQ.
*/

Rectangle {
    id: root

    /*!
       \qmlproperty var StatusCard::locale
       This property holds the locale used to interpret the number.
    */
    property var locale: Qt.locale()

    /*!
       \qmlproperty string StatusCard::disabledText
       This property is the text to be shown when the card is disabled
    */
    property string disabledText: ""
    /*!
       \qmlproperty bool StatusCard::disabled
        This property holds if the card is disbaled
    */
    property bool disabled: false

    /*!
       \qmlproperty bool StatusCard::clickable
        This property holds if the card is clickable
    */
    property bool clickable: true

    /*!
       \qmlproperty bool StatusCard::advancedMode
       This property holds if advanced mode is on for the StatusCard component
    */
    property bool advancedMode: false
    /*!
       \qmlproperty int StatusCard::lockTimeout
       This property enables user to customise the amount of time given to the user to enter a new value in
       advanced mode before it locked for any new changes
    */
    property int lockTimeout: 1500
    /*!
       \qmlproperty int StatusCard::locked
       This property holds if the custom amount entered by user is locked
    */
    property bool locked: false
    /*!
       \qmlproperty int StatusCard::preCalculatedAdvancedText
       This property is the amounts calculated by the routing algorithm
    */
    property string preCalculatedAdvancedText
    /*!
       \qmlproperty alias StatusCard::primaryText
       Used to set Primary text in the StatusCard
    */
    property alias primaryText: primaryText.text
    /*!
       \qmlproperty string StatusCard::secondaryText
       Used to set Secondary text in the StatusCard
    */
    property string secondaryText: ""
    /*!
       \qmlproperty alias StatusCard::tertiaryText
       Used to set Tertiary text in the StatusCard
    */
    property alias tertiaryText: tertiaryText.text
    /*!
       \qmlproperty alias StatusCard::disableText
       Used to set disable text in the StatusCard
    */
    property alias disableText: disableText.text
    /*!
       \qmlproperty alias StatusCard::enableText
       Used to set enableText text in the StatusCard
    */
    property string enableText
    /*!
       \qmlproperty alias StatusCard::advancedInputText
       Used to set text in the StatusInput in advancedMode
    */
    property alias advancedInputText: advancedInput.text
    /*!
       \qmlproperty alias StatusCard::errorIconName
       Used to assign an icon to the error icon in StatusCard
    */
    property alias errorIconName: errorIcon.icon
    /*!
       \qmlproperty alias StatusCard::cardIconName
       Used to assign an icon to the card icon in StatusCard
    */
    property alias cardIconName: cardIcon.icon

    /*!
       \qmlproperty alias StatusCard::primaryLabel
       This property allows user to customize the primary label in the StatusCard
    */
    property alias primaryLabel: primaryText
    /*!
       \qmlproperty alias StatusCard::secondaryLabel
       This property allows user to customize the secondary label in the StatusCard
    */
    property alias secondaryLabel: secondaryLabel
    /*!
       \qmlproperty alias StatusCard::tertiaryLabel
       This property allows user to customize the tertiary label in the StatusCard
    */
    property alias tertiaryLabel: tertiaryText
    /*!
       \qmlproperty alias StatusCard::advancedInput
       This property allows user to customize the StatusInput in advanced mode
    */
    property alias advancedInput: advancedInput
    /*!
       \qmlproperty alias StatusCard::errorIcon
       This property allows user to customize the error icon in the StatusCard
    */
    property alias errorIcon: errorIcon
    /*!
       \qmlproperty alias StatusCard::cardIcon
       This property allows user to customize the card icon in the StatusCard
    */
    property alias cardIcon: cardIcon
    /*!
       \qmlproperty real StatusCard::cardIconPosition
       This property exposes the card icon posistion to help draw the network routes
    */
    property real cardIconPosition: layout.y + cardIcon.y + cardIcon.height/2
    /*!
       \qmlproperty real StatusCard::maxAdvancedValue
       This property holds the max value in the advanced input that can be entered by the user
    */
    property real maxAdvancedValue
    /*!
       \qmlproperty real StatusCard::loading
       This property holds id the card is in loading state
    */
    property bool loading: false
    /*!
        \qmlsignal StatusCard::clicked
        This signal is emitted when the card is clicked
    */
    signal clicked()

    /*!
        \qmlsignal StatusCard::lockCard
        This signal is emitted when the card is locked or unlocked
    */
    signal lockCard(bool lock)

    /*!
       \qmlproperty string StatusCard::state
       This property holds the states of the StatusCard.
       Possible values are:
        \ "default" : Normal state
        \ "unavailable" : Unavailable state
        \ "unpreferred": Not preffered state
        \ "error" : Error state
    */
    state: "default"

    implicitHeight: 90
    implicitWidth: 160
    radius: 8
    border.width: 1
    border.color: Theme.palette.primaryColor2

    // This is used to create a shadow around the rectangle when hovered
    // it was needed to be done this way because it doesnt work with the
    // main rect when it is transparent in its "default" state
    Rectangle {
        id: dummyRect
        anchors.fill: parent
        radius: root.radius
        opacity: 0
    }
    DropShadow {
        anchors.fill: dummyRect
        verticalOffset: 0
        horizontalOffset: 0
        radius: 8
        samples: 17
        source: dummyRect
        color: Theme.palette.dropShadow
        visible: sensor.containsMouse
        z: root.z - 1
    }

    StatusMouseArea {
        id: sensor
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        enabled: root.clickable && root.state !== "unavailable"
        onClicked: root.clicked()
    }

    ColumnLayout {
        id: layout
        spacing: 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 8
        RowLayout {
            Layout.preferredWidth: layout.width
            StatusBaseText {
                id: primaryText
                Layout.maximumWidth: layout.width - cardIcon.width - 24
                font.pixelSize: Theme.primaryTextFontSize
                font.weight: Font.Medium
                elide: Text.ElideRight
                lineHeight: 22
                lineHeightMode: Text.FixedHeight
                verticalAlignment: Text.AlignVCenter
            }
            StatusIcon {
                id: cardIcon
                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                Layout.preferredHeight: 16
                Layout.preferredWidth: 16
            }
        }
        RowLayout {
            id: basicInput
            Layout.preferredHeight: 32
            StatusBaseText {
                id: secondaryLabel
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.pixelSize: Theme.additionalTextSize
                lineHeight: 18
                lineHeightMode: Text.FixedHeight
                verticalAlignment: Text.AlignVCenter
            }
            StatusIcon {
                id: errorIcon
                Layout.alignment: Qt.AlignVCenter
                width: 14
                height: 14
                icon: "tiny/warning"
                color: Theme.palette.pinColor1
            }
        }
        StatusAmountInput {
            id: advancedInput
            Layout.preferredWidth: layout.width
            maximumHeight: 32
            topPadding: 0
            bottomPadding: 0
            leftPadding: 8
            rightPadding: 5
            locale: root.locale
            input.edit.color: { // crash workaround, https://bugreports.qt.io/browse/QTBUG-107795
                if (root.state === "error")
                    return Theme.palette.dangerColor1
                if (root.locked)
                    return Theme.palette.directColor5
                return Theme.palette.directColor1
            }
            input.edit.font.pixelSize: Theme.additionalTextSize
            input.edit.readOnly: disabled
            input.background.radius: 4
            input.background.color: input.edit.activeFocus ? "transparent" : Theme.palette.directColor8
            input.background.border.color: input.edit.activeFocus ? Theme.palette.primaryColor2 : "transparent"
            input.rightComponent: Row {
                width: implicitWidth
                spacing: 4
                visible: root.state !== "error"
                StatusFlatRoundButton {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12
                    height: 12
                    icon.name: root.locked ? "lock" : "unlock"
                    icon.width: 12
                    icon.height: 12
                    icon.color: root.locked ? Theme.palette.primaryColor1 : Theme.palette.baseColor1
                    type: StatusFlatRoundButton.Type.Secondary
                    enabled: !disabled
                    onClicked: root.lockCard(!root.locked)
                }
            }
            validators: [
                StatusFloatValidator {
                    id: floatValidator
                    bottom: 0
                    top: root.maxAdvancedValue
                    errorMessage: ""
                    locale: root.locale
                }
            ]
            text: root.preCalculatedAdvancedText
            onTextChanged: waitTimer.restart()
            Timer {
                id: waitTimer
                interval: lockTimeout
                onTriggered: {
                    if(!!advancedInput.text && root.preCalculatedAdvancedText !== advancedInput.text) {
                        root.lockCard(true)
                    }
                }
            }
        }
        Loader {
            id: loadingComponent
            Layout.preferredHeight: active ? 32 : 0
            Layout.fillWidth: true
            active: false
            sourceComponent: LoadingComponent { radius: 4 }
        }
        StatusBaseText {
            id: tertiaryText
            Layout.maximumWidth: layout.width
            Layout.preferredHeight: 20
            elide: Text.ElideRight
            font.pixelSize: Theme.asideTextFontSize
            lineHeight: 14
            lineHeightMode: Text.FixedHeight
            verticalAlignment: Text.AlignVCenter
        }
        StatusBaseText {
            id: disableText
            Layout.maximumWidth: layout.width
            Layout.preferredHeight: 20
            elide: Text.ElideRight
            font.weight: Font.Medium
            color: Theme.palette.primaryColor1
            font.pixelSize: Theme.additionalTextSize
            lineHeight: 18
            lineHeightMode: Text.FixedHeight
            verticalAlignment: Text.AlignVCenter
        }
    }

    states: [
        State {
            name: "default"
            PropertyChanges {
                target: root
                color: disabled ? Theme.palette.baseColor4 : Theme.palette.indirectColor1
            }
            PropertyChanges {
                target: root
                border.color: Theme.palette.primaryColor2
            }
            PropertyChanges {
                target: primaryText
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: primaryText
                visible: primaryText.text
            }
            PropertyChanges {
                target: secondaryLabel
                color: disabled ? sensor.containsMouse ?
                                      Theme.palette.primaryColor1 :
                                      Theme.palette.directColor5: Theme.palette.primaryColor1
            }
            PropertyChanges {
                target: secondaryLabel
                visible: !advancedMode && secondaryLabel.text
            }
            PropertyChanges {
                target: secondaryLabel
                text: disabled ? sensor.containsMouse ? root.enableText : disabledText : secondaryText
            }
            PropertyChanges {
                target: secondaryLabel
                font.weight: disabled && sensor.containsMouse ? Font.Medium : Font.Normal
            }
            PropertyChanges {
                target: tertiaryText
                color: Theme.palette.directColor5
            }
            PropertyChanges {
                target: tertiaryText
                visible: advancedMode ? tertiaryText.text : (!sensor.containsMouse && tertiaryText.text) || disabled
            }
            PropertyChanges {
                target: disableText
                visible: sensor.containsMouse && !advancedMode && !disabled
            }
            PropertyChanges {
                target: cardIcon
                opacity: disabled ?  0.4 : 1
            }
            PropertyChanges {
                target: errorIcon
                visible: false
            }
            PropertyChanges {
                target: advancedInput
                visible: advancedMode
            }
            PropertyChanges {
                target: basicInput
                visible: !advancedMode && !(root.loading && !disabled)
            }
            PropertyChanges {
                target: loadingComponent
                active: root.loading && !advancedMode && !disabled
            }
        },
        State {
            name: "error"
            PropertyChanges {
                target: root
                color: disabled ? Theme.palette.baseColor4 : Theme.palette.indirectColor1
            }
            PropertyChanges {
                target: root
                border.color: Theme.palette.primaryColor2
            }
            PropertyChanges {
                target: primaryText
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: primaryText
                visible: primaryText.text
            }
            PropertyChanges {
                target: secondaryLabel
                color: disabled ? sensor.containsMouse ?
                                      Theme.palette.primaryColor1 :
                                      Theme.palette.directColor5: Theme.palette.dangerColor1
            }
            PropertyChanges {
                target: secondaryLabel
                visible: !advancedMode && secondaryLabel.text
            }
            PropertyChanges {
                target: secondaryLabel
                text: disabled ? sensor.containsMouse ? root.enableText : disabledText : secondaryText
            }
            PropertyChanges {
                target: secondaryLabel
                font.weight: disabled && sensor.containsMouse ? Font.Medium : Font.Normal
            }
            PropertyChanges {
                target: tertiaryText
                color: disabled ? Theme.palette.directColor5 : Theme.palette.dangerColor1
            }
            PropertyChanges {
                target: tertiaryText
                visible: advancedMode ? tertiaryText.text : (!sensor.containsMouse && tertiaryText.text) || disabled
            }
            PropertyChanges {
                target: disableText
                visible: sensor.containsMouse && !advancedMode && !disabled
            }
            PropertyChanges {
                target: cardIcon
                opacity: disabled ?  0.4 : 1
            }
            PropertyChanges {
                target: errorIcon
                visible: false
            }
            PropertyChanges {
                target: advancedInput
                visible: advancedMode
            }
            PropertyChanges {
                target: basicInput
                visible: !advancedMode && !(root.loading && !disabled)
            }
            PropertyChanges {
                target: loadingComponent
                active: root.loading && !advancedMode && !disabled
            }
        },
        State {
            name: "unpreferred"
            PropertyChanges {
                target: root
                color: disabled ? Theme.palette.baseColor4 : Theme.palette.indirectColor1
            }
            PropertyChanges {
                target: root
                border.color: Theme.palette.pinColor2
            }
            PropertyChanges {
                target: primaryText
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: primaryText
                visible: primaryText.text
            }
            PropertyChanges {
                target: secondaryLabel
                color: disabled ? sensor.containsMouse ?
                                      Theme.palette.primaryColor1 :
                                      Theme.palette.directColor5 : Theme.palette.pinColor1
            }
            PropertyChanges {
                target: secondaryLabel
                visible: !advancedMode && secondaryLabel.text
            }
            PropertyChanges {
                target: secondaryLabel
                text: disabled ? sensor.containsMouse ? root.enableText : disabledText : secondaryText
            }
            PropertyChanges {
                target: secondaryLabel
                font.weight: disabled && sensor.containsMouse ? Font.Medium : Font.Normal
            }
            PropertyChanges {
                target: tertiaryText
                color: Theme.palette.pinColor1
            }
            PropertyChanges {
                target: tertiaryText
                visible: advancedMode ? tertiaryText.text : (!sensor.containsMouse && tertiaryText.text) || disabled
            }
            PropertyChanges {
                target: disableText
                visible: sensor.containsMouse && !advancedMode && !disabled
            }
            PropertyChanges {
                target: cardIcon
                opacity: disabled ? 0.4 : 1
            }
            PropertyChanges {
                target: errorIcon
                visible: !disabled && !advancedMode
            }
            PropertyChanges {
                target: advancedInput
                visible: advancedMode
            }
            PropertyChanges {
                target: basicInput
                visible: !advancedMode && !(root.loading && !disabled)
            }
            PropertyChanges {
                target: loadingComponent
                active: root.loading && !advancedMode && !disabled
            }
        },
        State {
            name: "unavailable"
            PropertyChanges {
                target: root
                color: "transparent"
            }
            PropertyChanges {
                target: root
                border.color: "transparent"
            }
            PropertyChanges {
                target: primaryText
                color: Theme.palette.directColor5
            }
            PropertyChanges {
                target: primaryText
                visible: primaryText.text
            }
            PropertyChanges {
                target: secondaryLabel
                color: Theme.palette.directColor5
            }
            PropertyChanges {
                target: secondaryLabel
                visible: secondaryLabel.text
            }
            PropertyChanges {
                target: secondaryLabel
                text: secondaryText
            }
            PropertyChanges {
                target: secondaryLabel
                font.weight: disabled && sensor.containsMouse ? Font.Medium : Font.Normal
            }
            PropertyChanges {
                target: tertiaryText
                color: Theme.palette.directColor5
            }
            PropertyChanges {
                target: tertiaryText
                visible: advancedMode ? tertiaryText.text : (!sensor.containsMouse && tertiaryText.text) || disabled
            }
            PropertyChanges {
                target: disableText
                visible: sensor.containsMouse && !advancedMode && !disabled
            }
            PropertyChanges {
                target: cardIcon
                opacity: 0.4
            }
            PropertyChanges {
                target: errorIcon
                visible: false
            }
            PropertyChanges {
                target: advancedInput
                visible: false
            }
            PropertyChanges {
                target: basicInput
                visible: true
            }
            PropertyChanges {
                target: loadingComponent
                active: false
            }
        }
    ]
}
