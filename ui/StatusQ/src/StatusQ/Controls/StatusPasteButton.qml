import QtQuick
import QtQuick.Controls

import StatusQ
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Core.Utils as SQUtils

/*!
   \qmltype StatusPasteButton
   \brief A "Paste" button that never triggers the iOS paste permission prompt.

   On iOS the button is a native UIPasteControl: the system reads the pasteboard
   and hands the contents over, so the app never touches UIPasteboard and no
   "Allow Paste?" alert is shown. Its label is system-supplied and cannot be
   restyled beyond tint colours, so it will not match StatusButton exactly.

   Everywhere else it is a plain StatusButton reading the clipboard directly.

   Consumers must react to \c pasted rather than reading the clipboard
   themselves - reading it to decide enablement is what caused issues #21365
   and #21438.
*/
Control {
    id: root

    /*! Emitted with the pasted plain text once the paste is authorised. */
    signal pasted(string text)

    /*!
       Whether there is anything to paste. Always true on iOS: the clipboard
       cannot be inspected there without triggering the permission prompt, and
       the system disables its own control when the pasteboard is empty.
    */
    readonly property bool canPaste: SQUtils.Utils.isIOS || ClipboardUtils.hasText

    /*!
       Styling for the non-iOS StatusButton. Ignored on iOS, where the control
       is system-rendered and only its tint is configurable.
    */
    property int size: StatusBaseButton.Size.Tiny
    property color borderColor: "transparent"
    property int borderWidth: 0

    // StatusBaseButton's defaults, restated so the whole font group can be
    // handed to it: it binds family, weight and pixelSize itself, so a
    // consumer's font only reaches the label if it arrives as one group.
    font.family: Fonts.baseFont.family
    font.weight: Font.Medium
    font.pixelSize: {
        if (root.size === StatusBaseButton.Size.Large)
            return Theme.primaryTextFontSize
        return Theme.additionalTextSize
    }
    /*!
       Focus policy of the desktop button. Kept separate from the wrapper's own
       \c focusPolicy, which stays Qt.NoFocus so the composite does not add a
       second tab stop in front of the button.
    */
    property int buttonFocusPolicy: Qt.StrongFocus

    contentItem: Loader {
        sourceComponent: SQUtils.Utils.isIOS ? nativeComponent : buttonComponent
    }

    Component {
        id: nativeComponent

        NativePasteButtonItem {
            // Icon-only: the system label cannot be restyled to match
            // StatusButton and its width varies by locale, so the glyph keeps
            // this compact and locale-proof.
            // UIPasteControl reports no measurable size and CLIPS rather than
            // scales - below its floor it renders as a bare fill with nothing
            // in it. Measured on iOS 18: height 34 is the hard floor (33 is
            // blank at any width); width is free down to at least 34.
            implicitWidth: 36
            implicitHeight: 34
            displayMode: NativePasteButtonItem.IconOnly
            cornerStyle: NativePasteButtonItem.Capsule
            backgroundColor: Theme.palette.primaryColor3
            foregroundColor: Theme.palette.primaryColor1
            onPasted: (text) => root.pasted(text)
        }
    }

    Component {
        id: buttonComponent

        StatusButton {
            size: root.size
            borderColor: root.borderColor
            borderWidth: root.borderWidth
            // Forwarded one by one, not as a group: StatusBaseButton binds each
            // of these itself, and a whole-group assignment here does not
            // override those bindings.
            font.family: root.font.family
            font.weight: root.font.weight
            font.pixelSize: root.font.pixelSize
            focusPolicy: root.buttonFocusPolicy
            text: qsTr("Paste")
            enabled: root.canPaste
            onClicked: root.pasted(ClipboardUtils.text)
        }
    }
}
