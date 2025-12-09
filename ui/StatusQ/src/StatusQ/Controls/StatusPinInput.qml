import QtQuick

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls.Validators
import StatusQ.Core.Utils

/*!
   \qmltype StatusPinInput
   \inherits Item
   \inqmlmodule StatusQ.Controls
   \since StatusQ.Controls 0.1
   \brief It allows entering an N pin length.

   The \c StatusPinInput displays N visual circles corresponging with the pin length to introduce.

   It runs a blinking animation when the control is focused and ready to introduce the pin, as well as, an hovering feedback when user is in the StatusMouseArea where is able to click into the control.

   This pin input control allows introducing validators.

   Example of how the control looks like:
   \image status_pin_input.png

   Example of how to use it:

   \qml
        StatusPinInput {
            id: regexPinInput
            validator:  StatusRegularExpressionValidator { regularExpression: /[0-9A-Za-z@]+/ }
            circleDiameter: 22
            circleSpacing: 22
            pinLen: 7
        }
   \endqml

   For a list of components available see StatusQ.
*/
Item {
    id: root

    /*!
       \qmlproperty string StatusPinInput::pinInput
       This property holds the introduced user pin.
    */
    property alias pinInput: inputText.text

    /*!
       \qmlproperty StatusValidator StatusPinInput::validator
        This property allows you to set a validator on the StatusPinInput. When a validator is set the StatusPinInput will only accept
        input which leaves the pinInput property in an acceptable state.

        Currently supported validators are qml StatusIntValidator and StatusRegularExpressionValidator.

        An example of using validators is shown below, which allows input of integers between 0 and 999999 into the pin input

        \qml
            StatusPinInput {
                id: numbersPinInput
                validator: StatusIntValidator{bottom: 0; top: 999999;}
            }
        \endqml
    */
    property alias validator: d.statusValidator

    /*!
       \qmlproperty bool StatusPinInput::pinInput
       This property holds whether the entered PIN is valid; PIN is considered valid when it passes the internal validator
       and its length matches that of @p pinLen
    */
    readonly property bool valid: inputText.acceptableInput && inputText.length === pinLen

    /*!
       \qmlproperty int StatusPinInput::pinLen
       This property allows you to set a specific pin input length. The default value is 6.
    */
    property int pinLen: 6

    /*!
       \qmlproperty int StatusPinInput::circleSpacing
       This property allows you to customize spacing between pin circles. The default value is 16 pixels.
    */
    property int circleSpacing: 16

    /*!
       \qmlproperty int StatusPinInput::circleDiameter
       This property allows you to customize pin circle diameter. The default value is 16 pixels.
    */
    property int circleDiameter: 16

    /*!
       \qmlproperty int StatusPinInput::additionalSpacingOnEveryNItems
       This property allows you to customize spacing among every N-th pin. By default the value is 0, which
       means only regular `circleSpacing` will be applied, meaning that spacing among all pins will be the same.
    */
    property int additionalSpacingOnEveryNItems: 0

    /*!
       \qmlproperty int StatusPinInput::additionalSpacing
       This property allows you to customize spacing between pin circles on every `additionalSpacingOnEveryNItems` items.
       This additionalSpacing won't be applied if `additionalSpacingOnEveryNItems` is set to `0`.
    */
    property int additionalSpacing: 0

    /*!
       \qmlproperty flags StatusPinInput::inputMethodHints
       This property allows you to customize the input method hints for the virtual keyboard.
       The default value is Qt.ImhNone which allows any input based on the validator.
    */
    property int inputMethodHints: Qt.ImhNone

    signal pinEditedManually()

    QtObject {
        id: d
        property int currentPinIndex: 0

        property StatusValidator statusValidator

        function activateBlink () {
            const currItem = repeater.itemAt(d.currentPinIndex)
            if(currItem) {
                if((currItem.innerState === "NEXT") && (!currItem.blinkingAnimation.running)) {
                    currItem.blinkingAnimation.start()
                }
            }
        }

        function deactivateBlink () {
            const currItem = repeater.itemAt(d.currentPinIndex)
            if(currItem) {
                if((currItem.innerState === "NEXT") && (currItem.blinkingAnimation.running)) {
                    currItem.blinkingAnimation.stop()

                    // To ensure that the opacity does not remain in an intermediate state when forcing the animation to stop
                    currItem.innerOpacity = 1
                }
            }
        }
    }

    /*
        \qmlmethod StatusPinInput::statesInitialization()

        Initializes pin input bringing it to its initial state.

        It can be called whenever you need resetting it.
    */
    function statesInitialization() {
        d.currentPinIndex = 0
        let item = repeater.itemAt(d.currentPinIndex)
        if (item)
            item.innerState = "NEXT"
        for (var i = 1; i < root.pinLen; i++) {
            let item = repeater.itemAt(i)
            if (item)
                item.innerState = "EMPTY"
        }
        inputText.text = ""
    }

    /*
        \qmlmethod StatusPinInput::forceFocus()

        Convenient method to force active focus in case it gets stolen by any other component.
    */
    function forceFocus() {
        inputText.forceActiveFocus()
        if (Qt.inputMethod.visible == false) {
            Qt.inputMethod.show()
        }
        d.activateBlink()
    }

    /*
        \qmlmethod StatusPinInput::setPin(pin)

        Sets the pin input, setting state of each digit to "FILLED".

        It won't do anything if pin length is different from the set `pinLen`.
    */
    function setPin(pin) {
        if(pin.length !== root.pinLen)
            return

        d.currentPinIndex = root.pinLen - 1
        inputText.text = pin

        for (var i = 0; i < root.pinLen; i++) {
            const currItem = repeater.itemAt(i)
            currItem.innerState = "FILLED"
        }
    }

    /*
        \qmlmethod StatusPinInput::clearPin()

        Sets the pin input to an empty string, setting state of each digit to "EMPTY", and stops the blinking animation

        Doesn't change the current `pinLen`.
    */
    function clearPin() {
        inputText.text = ""
        d.currentPinIndex = 0
        d.deactivateBlink()
        for (var i = 0; i < root.pinLen; i++) {
            const currItem = repeater.itemAt(i)
            currItem.innerState = "EMPTY"
        }
    }

    implicitWidth: childrenRect.width
    implicitHeight: childrenRect.height

    // Pin input data management object:
    TextInput {
        id: inputText
        objectName: "pinInputTextInput"
        visible: true
        // Set explicit dimensions for Android keyboard input to work
        width: 1
        height: 1
        opacity: 0
        maximumLength: root.pinLen
        inputMethodHints: root.inputMethodHints
        // validator: d.statusValidator.validatorObj
        onTextChanged: {
            // Modify state of current introduced character position:
            if(text.length >= (d.currentPinIndex + 1)) {
                repeater.itemAt(d.currentPinIndex).innerState = "FILLED"

                // Update next:
                d.currentPinIndex++
                if(d.currentPinIndex < root.pinLen)
                    repeater.itemAt(d.currentPinIndex).innerState = "NEXT"

            }
            // Modify state of current removed character position:
            else if (text.length <= (d.currentPinIndex + 1)) {
                if(d.currentPinIndex < root.pinLen)
                    repeater.itemAt(d.currentPinIndex).innerState = "EMPTY"
                if(d.currentPinIndex > 0)
                    d.currentPinIndex--
                repeater.itemAt(d.currentPinIndex).innerState = "NEXT"
            }

            // Some component validations:
            if(text.length !== d.currentPinIndex)
                console.error("StatusPinInput input management error. Current pin length must be "+ text.length + " and is " + d.currentPinIndex)
        }
        onFocusChanged: { if(!focus) { d.deactivateBlink () } }
        onTextEdited: root.pinEditedManually()

        Keys.onShortcutOverride: (event) => event.accepted = event.matches(StandardKey.Paste)
        Keys.onPressed: (event) => {
                            if (event.matches(StandardKey.Paste)) {
                                root.setPin(ClipboardUtils.text)
                            }
                        }
    }

    // Pin input visual objects:
    Row {
        spacing: root.circleSpacing

        Repeater {
            id: repeater
            model: root.pinLen

            Item {
                id: container
                property string innerState: "EMPTY"
                property alias blinkingAnimation: blinkingAnimation
                property alias innerOpacity: inner.opacity

                height: root.circleDiameter
                width: {
                    if (index > 0 && index < root.pinLen-1 && (index+1) % root.additionalSpacingOnEveryNItems == 0) {
                        return root.circleDiameter + root.additionalSpacing
                    }
                    return root.circleDiameter
                }

                Rectangle {
                    width: root.circleDiameter
                    height: width
                    color: Theme.palette.primaryColor2
                    radius: 0.5 * width

                    Rectangle {
                        id: inner
                        state: container.innerState
                        anchors.centerIn: parent
                        height: width
                        color: Theme.palette.primaryColor1
                        radius: 0.5 * width
                        states: [
                            State {
                                name: "NEXT"
                                StateChangeScript { script: { if(inputText.focus) blinkingAnimation.start() } }
                                PropertyChanges {target: inner; width: root.circleDiameter / 2}
                            },
                            State {
                                name: "FILLED"
                                StateChangeScript { script: if(blinkingAnimation.running) blinkingAnimation.stop() }
                                PropertyChanges {target: inner; width: root.circleDiameter}
                                PropertyChanges {target: inner; opacity: 1}
                            },
                            State {
                                name: "EMPTY"
                                StateChangeScript { script: if(blinkingAnimation.running) blinkingAnimation.stop() }
                                PropertyChanges {target: inner; width: 0}
                                PropertyChanges {target: inner; opacity: 1}
                            }
                        ]

                        // Animation on transitions
                        Behavior on width { NumberAnimation { duration: 200 } }

                        // Animation on "cursor" blinking
                        SequentialAnimation {
                            id: blinkingAnimation
                            loops: Animation.Infinite
                            running: visible
                            NumberAnimation { target: inner; property: "opacity"; to: 0; duration: 800;}
                            NumberAnimation { target: inner; property: "opacity"; to: 1; duration: 800;}
                        }
                    }
                }
            }
        }
    }

    StatusMouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true

        // StatusMouseArea behavior:
        onClicked: forceFocus()
        onContainsMouseChanged: { if(containsMouse) { cursorShape = Qt.PointingHandCursor } }
    }
}
