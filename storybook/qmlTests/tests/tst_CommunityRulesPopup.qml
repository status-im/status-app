import QtQuick
import QtTest

import AppLayouts.Communities.popups

Item {
    id: root

    width: 1024
    height: 768

    Component {
        id: componentUnderTest

        CommunityRulesPopup {
            destroyOnClose: false
            name: "Status"
            introMessage: "Welcome to the Status community."
            image: ""
            color: "#887af9"
        }
    }

    property CommunityRulesPopup controlUnderTest: null

    TestCase {
        name: "CommunityRulesPopup"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root);
        }

        function cleanup() {
            if (controlUnderTest) {
                controlUnderTest.close();
                controlUnderTest.destroy();
                controlUnderTest = null;
            }
        }

        function openDialog() {
            verify(!!controlUnderTest);
            controlUnderTest.open();
            tryCompare(controlUnderTest, "opened", true);
        }

        function test_title_contains_community_name() {
            openDialog();
            verify(controlUnderTest.title.includes("Status"));
        }

        function test_done_button_closes_dialog() {
            openDialog();

            const doneButton = findChild(controlUnderTest, "communityRulesPopupDoneButton");
            verify(!!doneButton);

            mouseClick(doneButton);

            tryCompare(controlUnderTest, "opened", false);
        }

        function test_content_host_is_present() {
            openDialog();

            const contentHost = findChild(controlUnderTest, "statusAdaptiveDialogContentHost");
            verify(!!contentHost);
            verify(contentHost.visible);
        }
    }
}
