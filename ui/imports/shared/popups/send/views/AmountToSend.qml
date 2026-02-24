import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Validators

import utils
import shared.controls
import shared.panels

Control {
    id: root

    /* Crypto value in a base unit as a string integer, e.g. 1000000000000000000
     * for 1 ETH */
    readonly property alias amount: d.amountBaseUnit

    /* In fiat mode the input value is meant to be a fiat value, conversely,
     * crypto value otherwise. */
    readonly property alias fiatMode: d.fiatMode

    /* Indicates whether toggling the fiatMode is enabled for the user */
    property bool fiatInputInteractive: interactive

    /* Indicates if input represent valid number. E.g. empty input or containing
     * only decimal point is not valid. */
    readonly property alias valid: textField.acceptableInput
    readonly property bool empty: textField.length === 0

    // TODO: remove, temporarily for backward compatibility. External components
    // should not rely on formatted amount because formatting rules are internal
    // detail of that component.
    readonly property alias text: textField.text

    //  Normalized (delocalized) string representation: always uses "." as the decimal separator
    readonly property alias delocalized: d.inputDelocalized

    /* Decimal point character to be displayed. Both "." and "," will be
     * replaced by the provided decimal point on the fly.
     * Uses Qt.locale().decimalPoint directly (on mac number format can differ from region default format).
     * Setting locale externally will override this to that locale's separator. */
    property string decimalPoint: d.effectiveLocale.decimalPoint

    /* Number of fiat decimal places used to limit allowed decimal places in
     * fiatMode */
    property int fiatDecimalPlaces: 2

    /* Specifies how divisible given cryptocurrency is, e.g. 18 for ETH. Used
     * for limiting allowed decimal places and computing final amount as an
     * integer value */
    property int multiplierIndex: 18

    /* Price of one unit of given cryptocurrency (e.g. price for 1 ETH) */
    property real cryptoPrice: 1.0

    property alias caption: captionText.text
    property bool interactive: true

    /* Boolean flag decides whether divider is shown between main input
       area and bottom text */
    property bool dividerVisible

    /* This string holds the current main input area's currency symbol (fiat or crypto)
       Not set = not shown */
    property string selectedSymbol

    readonly property bool cursorVisible: textField.cursorVisible
    readonly property alias placeholderText: textField.placeholderText

    /* Loading states for the input and text below */
    property bool mainInputLoading
    property bool bottomTextLoading

    /* This allows user to add a component to the right of bottom text
       Not set = not shown */
    property alias bottomRightComponent: bottomRightComponent.sourceComponent

    /* Allows mark input as invalid when it's valid number but doesn't satisfy
     * arbitrary external criteria, e.g. is higher than maximum expected value. */
    property bool markAsInvalid: false

    /* Right padding for amount input */
    property int amountInputRightPadding: 0
    /* Methods for formatting crypto and fiat value expecting double values,
       e.g. 1.0 for 1 ETH or 1.0 for 1 USD. */
    property var formatFiat: balance =>
                             `${balance.toLocaleString(Qt.locale())} FIAT`
    property var formatBalance: balance =>
                                `${balance.toLocaleString(Qt.locale())} CRYPTO`

    /* Allows to set value to be displayed. The value is expected to be a not
       localized string like "1", "1.1" or "0.000000023400234222". Provided
       value will be formatted and displayed. Depending on the fiatMode flag
       it will affect output amount appropriately. */
    function setValue(valueString) {
        if (!valueString)
            valueString = "0"

        const decimalPlaces = d.fiatMode ? root.fiatDecimalPlaces
                                         : root.multiplierIndex

        const stringNumber = SQUtils.AmountsArithmetic.fromString(
                               valueString).toFixed(decimalPlaces)

        const trimmed = d.fiatMode
                      ? stringNumber
                      : d.removeDecimalTrailingZeros(stringNumber)

        textField.text = d.localize(trimmed)
        textField.cursorPosition = 0
    }

    function setRawValue(valueString) {
        if (!valueString)
            valueString = "0"

        if (d.fiatMode) {
            setValue(valueString)
            return
        }

        const divisor = SQUtils.AmountsArithmetic.fromExponent(root.multiplierIndex)
        const stringNumber = SQUtils.AmountsArithmetic.div(SQUtils.AmountsArithmetic.fromString(valueString), divisor).toFixed(root.multiplierIndex)
        const trimmed = d.removeDecimalTrailingZeros(stringNumber)

        textField.text = d.localize(trimmed)
        textField.cursorPosition = 0
    }

    function clear() {
        textField.clear()
    }

    function forceActiveFocus() {
        if (SQUtils.Utils.isMobile)
            return
        textField.forceActiveFocus()
    }

    TapHandler {
        enabled: root.interactive
        onTapped: {
            textField.forceActiveFocus()
            if (SQUtils.Utils.isMobile && !Qt.inputMethod.visible)
                Qt.inputMethod.show()
        }
    }

    QtObject {
        id: d

        property bool fiatMode: false

        readonly property var effectiveLocale: {
            const name = root.locale.name
            if (name.length > 1 && name !== "C" && name !== Qt.locale().name)
                return Qt.locale(name)
            return Qt.locale()
        }

        readonly property string inputDelocalized:
            textField.length !== 0
            ? textField.text.replace(root.decimalPoint, ".") : "0"

        function removeDecimalTrailingZeros(num) {
            if (!num.includes("."))
                return num

            return num.replace(/\.?0*$/g, "")
        }

        function localize(num) {
            return num.replace(".", root.decimalPoint)
        }

        readonly property string amountBaseUnit: {
            if (d.fiatMode)
                return secondaryValue

            const multiplier = SQUtils.AmountsArithmetic.fromExponent(
                                 root.multiplierIndex)

            return SQUtils.AmountsArithmetic.times(
                        SQUtils.AmountsArithmetic.fromString(inputDelocalized),
                        multiplier).toFixed()
        }

        readonly property string secondaryValue: {
            const price = isNaN(root.cryptoPrice) ? 0 : root.cryptoPrice

            if (!d.fiatMode)
                return SQUtils.AmountsArithmetic.times(
                            SQUtils.AmountsArithmetic.fromString(inputDelocalized),
                            SQUtils.AmountsArithmetic.fromNumber(
                                price * (10 ** root.fiatDecimalPlaces))).toFixed()

            if (!price) // prevent div by zero below
                return 0

            const multiplier = SQUtils.AmountsArithmetic.fromExponent(
                                 root.multiplierIndex)

            return SQUtils.AmountsArithmetic.div(
                        SQUtils.AmountsArithmetic.times(
                            SQUtils.AmountsArithmetic.fromString(inputDelocalized),
                            multiplier),
                        SQUtils.AmountsArithmetic.fromNumber(price)).toFixed(0)
        }
    }

    contentItem: ColumnLayout {
        spacing: Theme.halfPadding
        StatusBaseText {
            id: captionText

            Layout.fillWidth: true

            visible: text.length > 0

            font.pixelSize: Theme.additionalTextSize
            lineHeight: 18
            lineHeightMode: Text.FixedHeight
            color: Theme.palette.directColor1
            elide: Text.ElideRight
        }

        RowLayout {
            id: layout
            spacing: 4

            StatusTextField {
                id: textField

                objectName: "amountToSend_textField"

                Layout.preferredHeight: 44
                Layout.maximumWidth: root.width - currencyField.width - 2*layout.spacing - root.amountInputRightPadding
                padding: 0
                leftPadding: 0
                background: null

                inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhNoPredictiveText

                readOnly: !root.interactive

                color: text.length === 0 || (root.valid && !root.markAsInvalid)
                       ? Theme.palette.directColor1
                       : Theme.palette.dangerColor1

                placeholderText: {
                    if (!d.fiatMode || root.fiatDecimalPlaces === 0 || !!text)
                        return "0"

                    return "0" + root.decimalPoint
                            + "0".repeat(root.fiatDecimalPlaces)
                }

                font.pixelSize: Theme.fontSize(34)

                validator: AmountValidator {
                    id: validator

                    maxIntegralDigits: 100
                    maxDecimalDigits: d.fiatMode ? root.fiatDecimalPlaces
                                                 : root.multiplierIndex
                    decimalPoint: root.decimalPoint
                }
                visible: !root.mainInputLoading

                // handle TextField scroll and click to change cursor position
                StatusMouseArea {
                    anchors.fill: parent
                    enabled: textField.focus
                    cursorShape: Qt.IBeamCursor
                    onClicked: (mouse) => {
                        textField.cursorPosition = textField.positionAt(mouse.x,mouse.y)
                        textField.forceActiveFocus()
                    }
                    onWheel: {
                        if(wheel.angleDelta.y>0)
                            textField.cursorPosition -= 1
                        if(wheel.angleDelta.y<0)
                            textField.cursorPosition += 1
                    }
                }
            }
            LoadingComponent {
                objectName: "topAmountToSendInputLoadingComponent"
                Layout.preferredWidth: textField.width
                Layout.preferredHeight: textField.height
                visible: root.mainInputLoading
            }
            StatusBaseText {
                id: currencyField

                objectName: "amountToSend_currencyField"

                Layout.alignment: Qt.AlignVCenter
                Layout.topMargin: 10

                color: Theme.palette.directColor5
                text: selectedSymbol
                font.pixelSize: Theme.additionalTextSize
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.bottomMargin: 4
            color: Theme.palette.directColor8
            visible: root.dividerVisible
        }

        RowLayout {
            Layout.fillWidth: true
            StatusTextWithLoadingState {
                id: bottomItem

                objectName: "bottomItemText"

                Layout.preferredWidth: contentWidth

                text: {
                    if (!d.fiatMode && root.cryptoPrice === 0) {
                        return ""
                    }
                    const divisor = SQUtils.AmountsArithmetic.fromExponent(
                                      d.fiatMode ? root.multiplierIndex
                                                 : root.fiatDecimalPlaces)
                    const divided = SQUtils.AmountsArithmetic.div(
                                      SQUtils.AmountsArithmetic.fromString(
                                          d.secondaryValue), divisor)
                    const asNumber = SQUtils.AmountsArithmetic.toNumber(divided)

                    return d.fiatMode ? root.formatBalance(asNumber)
                                      : root.formatFiat(asNumber)
                }

                elide: Text.ElideMiddle
                font.pixelSize: Theme.additionalTextSize
                customColor: Theme.palette.directColor5
                loading: root.bottomTextLoading

                StatusMouseArea {
                    objectName: "amountToSend_mouseArea"

                    anchors.fill: parent
                    cursorShape: enabled ? Qt.PointingHandCursor : undefined
                    enabled: root.fiatInputInteractive

                    onClicked: {
                        const secondaryValue = d.secondaryValue

                        d.fiatMode = !d.fiatMode

                        if (textField.length === 0)
                            return

                        const decimalPlaces = d.fiatMode ? root.fiatDecimalPlaces
                                                         : root.multiplierIndex
                        const divisor = SQUtils.AmountsArithmetic.fromExponent(
                                          decimalPlaces)

                        const stringNumber = SQUtils.AmountsArithmetic.div(
                                               SQUtils.AmountsArithmetic.fromString(secondaryValue),
                                               divisor).toFixed(decimalPlaces)

                        const trimmed = d.fiatMode
                                      ? stringNumber
                                      : d.removeDecimalTrailingZeros(stringNumber)

                        textField.text = d.localize(trimmed)
                        textField.cursorPosition = 0
                    }
                }

                HoverHandler { id: hoverHandler }
            }
            StatusIcon {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft

                icon: "swap"
                rotation: 90
                color: Theme.palette.directColor5
                visible: hoverHandler.hovered && root.fiatInputInteractive
            }
            Item { Layout.fillWidth: true }
            Loader {
                id: bottomRightComponent
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
