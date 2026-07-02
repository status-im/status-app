import QtQuick
import QtTest

import shared.popups

Item {
    id: root

    width: 1024
    height: 768

    Component {
        id: componentUnderTest

        ConfirmationDialog {
            confirmButtonObjectName: "confirmationDialogConfirmButton"
            confirmationText: "Confirm the real flow"
            confirmButtonLabel: "Confirm"
            showCancelButton: true
        }
    }

    Component {
        id: deleteMessageComponentUnderTest

        DeleteMessageConfirmationPopup {
            messageId: "test-message-id"
        }
    }

    property ConfirmationDialog controlUnderTest: null

    SignalSpy {
        id: confirmSpy
        target: controlUnderTest
        signalName: "confirmButtonClicked"
    }

    SignalSpy {
        id: cancelSpy
        target: controlUnderTest
        signalName: "cancelButtonClicked"
    }

    TestCase {
        name: "ConfirmationDialog"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root);
            confirmSpy.clear();
            cancelSpy.clear();
        }

        function cleanup() {
            if (controlUnderTest) {
                controlUnderTest.close();
                controlUnderTest.destroy();
                controlUnderTest = null;
            }
            confirmSpy.clear();
            cancelSpy.clear();
        }

        function openDialog() {
            verify(!!controlUnderTest);
            controlUnderTest.open();
            tryCompare(controlUnderTest, "opened", true);
        }

        function test_do_not_show_again_option_updates_state() {
            compare(controlUnderTest.doNotShowAgainOptionVisible, false);
            compare(controlUnderTest.doNotShowAgainChecked, false);

            controlUnderTest.doNotShowAgainOptionVisible = true;
            controlUnderTest.doNotShowAgainChecked = true;
            openDialog();

            const checkbox = findChild(controlUnderTest, "confirmationDialogDoNotShowAgainCheckBox");
            verify(!!checkbox);
            compare(checkbox.checked, true);

            mouseClick(checkbox);

            compare(controlUnderTest.doNotShowAgainChecked, false);
        }

        function test_confirm_button_emits_signal() {
            openDialog();

            const confirmButton = findChild(controlUnderTest, "confirmationDialogConfirmButton");
            verify(!!confirmButton);

            mouseClick(confirmButton);

            compare(confirmSpy.count, 1);
            compare(cancelSpy.count, 0);
        }

        function test_cancel_button_emits_signal() {
            openDialog();

            const cancelButton = findChild(controlUnderTest, "confirmationDialogCancelButton");
            verify(!!cancelButton);

            mouseClick(cancelButton);

            compare(cancelSpy.count, 1);
            compare(confirmSpy.count, 0);
        }

        function test_delete_message_confirmation_does_not_scroll_when_content_fits() {
            const popup = createTemporaryObject(deleteMessageComponentUnderTest, root);
            verify(!!popup);

            popup.open();
            tryCompare(popup, "opened", true);

            const scrollFlickable = findChild(popup, "statusAdaptiveDialogScrollFlickable");
            const scrollBar = findChild(popup, "statusAdaptiveDialogContentScrollBar");
            verify(!!scrollFlickable);
            verify(!!scrollBar);
            verify(scrollFlickable.contentHeight <= scrollFlickable.height);
            verify(!scrollBar.visible);

            popup.close();
        }
    }
}
