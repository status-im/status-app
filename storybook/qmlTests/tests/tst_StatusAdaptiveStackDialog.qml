import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtTest

import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups.Dialog

Item {
    id: root

    Window {
        id: testWindow

        width: ThemeUtils.portraitBreakpoint.width + 240
        height: ThemeUtils.portraitBreakpoint.height + 240
        visible: true
    }

    Component {
        id: stackDialogComponent

        StatusAdaptiveStackDialog {
            id: dialog

            property int backActionCount: 0

            maximumWidthOverride: 420
            stackContentImplicitHeight: 160
            initialItem: firstStepComponent

            Component {
                id: firstStepComponent

                Item {
                    property string title: "First step"
                    property string nextButtonObjectName: "stackNextButton"
                    property string nextButtonText: "Next"
                    property bool canGoNext: true
                    property var nextAction: () => dialog.stack.push(secondStepComponent)

                    objectName: "firstStep"
                    implicitHeight: 120
                }
            }

            Component {
                id: secondStepComponent

                Item {
                    property string title: "Second step"
                    property string nextButtonText: "Done"
                    property bool canGoNext: false
                    property var backAction: () => dialog.backActionCount++

                    objectName: "secondStep"
                    implicitHeight: 140
                }
            }
        }
    }

    Component {
        id: replaceDialogComponent

        StatusAdaptiveStackDialog {
            maximumWidthOverride: 420
            stackContentImplicitHeight: 160
            initialItem: baseStepComponent
            property Component replaceStep: replaceStepComponent

            Component {
                id: baseStepComponent

                Item {
                    property string title: "Base step"

                    objectName: "baseStep"
                    implicitHeight: 100
                }
            }

            Component {
                id: replaceStepComponent

                Item {
                    property string title: "Replace step"
                    property var rightButtons: StatusButton {
                        objectName: "replaceDoneButton"
                        text: "Replace done"
                    }

                    objectName: "replaceStep"
                    implicitHeight: 110
                }
            }
        }
    }

    Component {
        id: subHeaderDialogComponent

        StatusAdaptiveStackDialog {
            maximumWidthOverride: 420
            initialItem: contentStepComponent
            subHeaderPadding: 12
            subHeaderItem: Component {
                Item {
                    objectName: "stackSubHeader"
                    implicitHeight: 24
                }
            }

            Component {
                id: contentStepComponent

                Item {
                    property string title: "Content step"

                    objectName: "contentStep"
                    implicitHeight: 80
                }
            }
        }
    }

    Component {
        id: nestedScrollbarDialogComponent

        StatusAdaptiveStackDialog {
            maximumWidthOverride: 420
            stackContentImplicitHeight: 160
            initialItem: nestedScrollbarStepComponent

            Component {
                id: nestedScrollbarStepComponent

                Item {
                    objectName: "nestedScrollbarStep"
                    implicitHeight: 120
                    readonly property ScrollBar statusAdaptiveDialogContentVerticalScrollBar: nestedScrollBar

                    ScrollBar {
                        id: nestedScrollBar
                        policy: ScrollBar.AsNeeded
                    }
                }
            }
        }
    }

    Component {
        id: adaptiveHeightDialogComponent

        StatusAdaptiveStackDialog {
            id: dialog

            maximumWidthOverride: 420
            initialItem: shortStepComponent

            Component {
                id: shortStepComponent

                Item {
                    property string title: "Short step"
                    property string nextButtonText: "Next"
                    property var nextAction: () => dialog.stack.push(tallStepComponent)

                    implicitHeight: 80
                }
            }

            Component {
                id: tallStepComponent

                Item {
                    property string title: "Tall step"

                    implicitHeight: 180
                }
            }
        }
    }

    property StatusAdaptiveStackDialog controlUnderTest: null

    TestCase {
        name: "StatusAdaptiveStackDialog"
        when: windowShown

        function cleanup() {
            if (root.controlUnderTest) {
                root.controlUnderTest.close();
                root.controlUnderTest.destroy();
                root.controlUnderTest = null;
            }
        }

        function openDialog(component) {
            root.controlUnderTest = createTemporaryObject(component, testWindow.contentItem);
            verify(!!root.controlUnderTest);
            root.controlUnderTest.open();
            tryCompare(root.controlUnderTest, "opened", true);
            verify(!!root.controlUnderTest.stack);
            return root.controlUnderTest;
        }

        function test_stackNavigationAndBackAction() {
            const dialog = openDialog(stackDialogComponent);
            const nextButton = findChild(dialog, "stackNextButton");
            const footer = findChild(dialog, "statusAdaptiveDialogFooter");
            verify(!!nextButton);
            verify(!!footer);
            verify(nextButton.enabled);
            verify(nextButton.visible);
            verify(nextButton.width > 0);
            verify(nextButton.height > 0);
            wait(300);
            verify(footer.height >= nextButton.height);
            verify(nextButton.mapToItem(null, 0, nextButton.height).y <= dialog.y + dialog.height);
            verify(nextButton.mapToItem(null, 0, nextButton.height).y <= footer.mapToItem(null, 0, footer.height).y);

            compare(dialog.depth, 1);
            compare(dialog.currentIndex, 0);
            compare(dialog.title, "First step");

            mouseClick(nextButton, Qt.LeftButton);
            tryCompare(dialog, "depth", 2);
            compare(dialog.currentIndex, 1);
            compare(dialog.title, "Second step");

            dialog.back();
            tryCompare(dialog, "depth", 1);
            compare(dialog.backActionCount, 1);
            compare(dialog.title, "First step");
        }

        function test_replaceItemOverridesTitleAndBackClearsIt() {
            const dialog = openDialog(replaceDialogComponent);

            dialog.replace(dialog.replaceStep);
            tryCompare(dialog, "title", "Replace step");
            verify(!!dialog.replaceObject);
            verify(dialog.showStackBackButton);
            verify(findChild(dialog, "replaceDoneButton"));

            dialog.back();
            tryCompare(dialog, "replaceObject", null);
            compare(dialog.title, "Base step");
            compare(dialog.depth, 1);
        }

        function test_subHeaderContributesToImplicitHeight() {
            const dialog = openDialog(subHeaderDialogComponent);

            verify(findChild(dialog, "stackSubHeader"));
            compare(dialog.contentItem.naturalHeight, 80 + 24 + 12);
        }

        function test_nestedStepScrollbarIsDisabledByContentHost() {
            const dialog = openDialog(nestedScrollbarDialogComponent);

            verify(!!dialog.currentItem.statusAdaptiveDialogContentVerticalScrollBar);
            tryCompare(dialog.currentItem.statusAdaptiveDialogContentVerticalScrollBar,
                       "policy", ScrollBar.AlwaysOff);
        }

        function test_contentHeightKeepsLargestVisitedStackPage() {
            const dialog = openDialog(adaptiveHeightDialogComponent);

            compare(dialog.contentItem.naturalHeight, 80);
            dialog.currentItem.nextAction();
            tryCompare(dialog, "depth", 2);
            tryCompare(dialog.contentItem, "naturalHeight", 180);

            dialog.back();
            tryCompare(dialog, "depth", 1);
            compare(dialog.contentItem.naturalHeight, 180);
        }

    }
}
