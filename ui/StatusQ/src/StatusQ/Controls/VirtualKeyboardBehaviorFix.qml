import QtQml
import QtQuick

import StatusQ.Core
import StatusQ.Core.Utils

// Prevent Qt from calling forceActiveFocus() internally on every press.
// Without this, tapping an already-focused field triggers focusObjectChanged()
// in QAndroidInputContext, which hides then reshows the keyboard with animation
// on Android. The problem doesn't exist on IOS.
TapHandler {
    id: root

    enabled: Utils.isAndroid

    readonly property Binding binding_: Binding {
        target: root.target
        property: "activeFocusOnPress"
        value:!Utils.isAndroid
    }

    // Only take focus when not already focused or virtual keybaord is hidden
    onTapped: {
        const kbdHidden = SystemUtils.androidKeyboardHeight === 0

        if (!root.target.activeFocus || kbdHidden) {
            root.target.forceActiveFocus()

            if (kbdHidden)
                SystemUtils.requestAndroidKeyboardShow()
        }
    }
}
