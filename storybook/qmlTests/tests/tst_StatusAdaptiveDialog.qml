import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQml.Models
import QtTest

import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups.Dialog

Item {
    id: root

    width: d.desktopWindowWidth
    height: d.desktopWindowHeight

    Window {
        id: testWindow

        width: d.desktopWindowWidth
        height: d.desktopWindowHeight
        visible: true
    }

    Component {
        id: dialogComponent

        StatusAdaptiveDialog {
            objectName: "defaultDialog"
            title: "Default dialog"
            maximumWidthOverride: 420
            contentComponent: Component {
                Item {
                    implicitHeight: 120
                }
            }
            footerRightButtons: ObjectModel {
                StatusButton {
                    text: "Done"
                }
            }
        }
    }

    Component {
        id: modalOverrideDialogComponent

        StatusAdaptiveDialog {
            objectName: "modalOverrideDialog"
            modal: false
            contentComponent: Component {
                Item {
                    implicitHeight: 80
                }
            }
        }
    }

    Component {
        id: adaptiveWidthDialogComponent

        StatusAdaptiveDialog {
            objectName: "adaptiveWidthDialog"
            title: "Adaptive width dialog"
            contentComponent: Component {
                Item {
                    implicitHeight: 120
                }
            }
            footerRightButtons: ObjectModel {
                StatusButton {
                    text: "Done"
                }
            }
        }
    }

    Component {
        id: destroyOnCloseDialogComponent

        StatusAdaptiveDialog {
            property QtObject marker

            destroyOnClose: true
            contentComponent: Component {
                Item {
                    implicitHeight: 80
                }
            }

            Component.onDestruction: marker.wasDestroyed = true
        }
    }

    Component {
        id: tallRegularContentDialogComponent

        StatusAdaptiveDialog {
            maximumWidthOverride: 420
            maximumHeightOverride: 260
            title: "Tall content"
            contentComponent: Component {
                Item {
                    objectName: "regularContent"
                    implicitHeight: 600
                }
            }
            footerRightButtons: ObjectModel {
                StatusButton {
                    text: "Done"
                }
            }
        }
    }

    Component {
        id: flickableContentDialogComponent

        StatusAdaptiveDialog {
            maximumWidthOverride: 420
            maximumHeightOverride: 260
            contentComponent: Component {
                ListView {
                    objectName: "flickableContent"
                    implicitHeight: contentHeight
                    model: 30
                    delegate: Item {
                        width: ListView.view.width
                        height: 40
                    }
                }
            }
        }
    }

    Component {
        id: internalPopupComponent

        StatusAdaptiveDialog {
            objectName: "internalPopupContent"
            maximumWidthOverride: 240
            contentComponent: Component {
                Item {
                    implicitHeight: 120
                }
            }
        }
    }

    Component {
        id: tallInternalPopupComponent

        StatusAdaptiveDialog {
            objectName: "tallInternalPopupContent"
            maximumWidthOverride: 240
            contentComponent: Component {
                Item {
                    implicitHeight: 600
                }
            }
        }
    }

    Component {
        id: internalAdaptiveDialogComponent

        StatusAdaptiveDialog {
            objectName: "internalAdaptiveDialog"
            title: "Internal dialog"
            maximumWidthOverride: 240
            contentComponent: Component {
                Item {
                    implicitHeight: 600
                }
            }
        }
    }

    QtObject {
        id: d

        readonly property int desktopWindowWidth: ThemeUtils.portraitBreakpoint.width + 240
        readonly property int desktopWindowHeight: ThemeUtils.portraitBreakpoint.height + 240
        readonly property int mobileWindowWidth: ThemeUtils.portraitBreakpoint.width - 220
        readonly property int mobileWindowHeight: ThemeUtils.portraitBreakpoint.height + 260
    }

    property StatusAdaptiveDialog controlUnderTest: null

    TestCase {
        name: "StatusAdaptiveDialog"
        when: windowShown

        function init() {
            setTestWindowSize(d.desktopWindowWidth, d.desktopWindowHeight);
            controlUnderTest = createTemporaryObject(dialogComponent, testWindow.contentItem);
        }

        function cleanup() {
            if (controlUnderTest) {
                controlUnderTest.close();
                controlUnderTest.destroy();
                controlUnderTest = null;
            }
            root.width = d.desktopWindowWidth;
            root.height = d.desktopWindowHeight;
            setTestWindowSize(d.desktopWindowWidth, d.desktopWindowHeight);
        }

        function setTestWindowSize(width, height) {
            testWindow.width = width;
            testWindow.height = height;
            tryCompare(testWindow, "width", width);
            tryCompare(testWindow, "height", height);
            root.width = width;
            root.height = height;
        }

        function findInternalPopupLayer() {
            const popupLayer = findChild(controlUnderTest.Overlay.overlay, "statusAdaptiveDialogInternalPopupLayer");
            verify(!!popupLayer);
            return popupLayer;
        }

        function findInternalOverlay() {
            const overlay = findChild(controlUnderTest.Overlay.overlay, "statusAdaptiveDialogInternalOverlay");
            verify(!!overlay);
            return overlay;
        }

        function verifyInternalLayerMatchesParent(popupLayer, overlay) {
            tryCompare(popupLayer, "x", controlUnderTest.x);
            tryCompare(popupLayer, "y", controlUnderTest.y);
            tryCompare(popupLayer, "width", controlUnderTest.width);
            tryCompare(popupLayer, "height", controlUnderTest.height);
            compare(overlay.width, popupLayer.width);
            compare(overlay.height, popupLayer.height);
        }

        function verifyInternalDialogBottomAligned(popupLayer) {
            verify(!!popupLayer.popupObject);
            tryCompare(popupLayer.popupObject, "opened", true);
            tryCompare(popupLayer.popupObject, "width", popupLayer.width);
            compare(popupLayer.popupObject.x, 0);
            compare(popupLayer.popupObject.y, popupLayer.height - popupLayer.popupObject.height);
        }

        function setDialogSafeArea(top, bottom, left, right) {
            controlUnderTest.contentItem.SafeArea.additionalMargins.top = top;
            controlUnderTest.contentItem.SafeArea.additionalMargins.bottom = bottom;
            controlUnderTest.contentItem.SafeArea.additionalMargins.left = left;
            controlUnderTest.contentItem.SafeArea.additionalMargins.right = right;
        }

        function verifyDialogSafeAreaLayout(top, bottom, left, right) {
            const edgePadding = Math.max(Theme.padding, 8);
            const header = findChild(controlUnderTest, "statusAdaptiveDialogHeader");
            const footer = findChild(controlUnderTest, "statusAdaptiveDialogFooter");
            verify(!!header);
            verify(!!footer);

            tryCompare(header, "x", edgePadding + left);
            compare(header.y, edgePadding + top);
            compare(header.width, controlUnderTest.width - 2 * edgePadding - left - right);

            tryCompare(footer, "x", edgePadding + left);
            compare(footer.width, controlUnderTest.width - 2 * edgePadding - left - right);
            compare(footer.mapToItem(null, 0, footer.height).y,
                    controlUnderTest.y + controlUnderTest.height - edgePadding - bottom);
        }

        function test_centered_on_desktop() {
            controlUnderTest.open();
            tryCompare(controlUnderTest, "opened", true);

            compare(controlUnderTest.width, 420);
            verify(controlUnderTest.height > 0);
            verify(controlUnderTest.x > 0);
            verify(controlUnderTest.y > 0);
        }

        function test_default_header_uses_toolbar_with_parent_divider() {
            controlUnderTest.open();
            tryCompare(controlUnderTest, "opened", true);

            const toolbar = findChild(controlUnderTest, "statusAdaptiveDialogHeader");
            verify(!!toolbar);
            compare(toolbar.objectName, "statusAdaptiveDialogHeader");
            compare(controlUnderTest.title, "Default dialog");
            const edgePadding = Math.max(Theme.padding, 8);
            compare(toolbar.x, edgePadding);
            compare(toolbar.y, edgePadding);
            compare(toolbar.width, controlUnderTest.width - 2 * edgePadding);

            const divider = findChild(controlUnderTest, "statusAdaptiveDialogHeaderDivider");
            verify(!!divider);
            tryCompare(divider, "visible", true);
            compare(divider.height, 1);
            compare(divider.width, controlUnderTest.width);
            compare(divider.y, toolbar.height + 2 * edgePadding);
        }

        function test_default_footer_uses_toolbar_with_parent_divider() {
            controlUnderTest.open();
            tryCompare(controlUnderTest, "opened", true);

            const toolbar = findChild(controlUnderTest, "statusAdaptiveDialogFooter");
            verify(!!toolbar);
            compare(toolbar.objectName, "statusAdaptiveDialogFooter");
            const edgePadding = Math.max(Theme.padding, 8);
            compare(toolbar.x, edgePadding);
            compare(toolbar.width, controlUnderTest.width - 2 * edgePadding);

            const divider = findChild(controlUnderTest, "statusAdaptiveDialogFooterDivider");
            verify(!!divider);
            tryCompare(divider, "visible", true);
            compare(divider.height, 1);
            compare(divider.width, controlUnderTest.width);
        }

        function test_internal_popup_opens_in_parent_overlay_and_closes_from_overlay() {
            controlUnderTest.internalPopupComponent = internalPopupComponent;
            controlUnderTest.open();
            tryCompare(controlUnderTest, "opened", true);

            controlUnderTest.openInternalPopup();

            const popupLayer = findInternalPopupLayer();
            const overlay = findInternalOverlay();
            tryCompare(controlUnderTest, "internalPopupActive", true);
            tryCompare(popupLayer, "visible", true);
            verify(!!popupLayer.popupObject);
            compare(popupLayer.popupObject.objectName, "internalPopupContent");
            tryCompare(popupLayer.popupObject, "opened", true);
            verifyInternalLayerMatchesParent(popupLayer, overlay);

            mouseClick(overlay, overlay.width / 2, Theme.padding);

            tryCompare(controlUnderTest, "internalPopupActive", false);
            verify(!popupLayer.popupObject);
        }

        function test_internal_popup_is_reset_when_parent_dialog_closes() {
            controlUnderTest.internalPopupComponent = internalPopupComponent;
            controlUnderTest.open();
            tryCompare(controlUnderTest, "opened", true);

            controlUnderTest.openInternalPopup();
            tryCompare(controlUnderTest, "internalPopupActive", true);

            controlUnderTest.close();

            tryCompare(controlUnderTest, "opened", false);
            tryCompare(controlUnderTest, "internalPopupActive", false);
        }

        function test_internal_popup_height_is_capped_by_parent_dialog() {
            controlUnderTest.internalPopupComponent = tallInternalPopupComponent;
            controlUnderTest.open();
            tryCompare(controlUnderTest, "opened", true);

            controlUnderTest.openInternalPopup();

            const popupLayer = findInternalPopupLayer();
            verify(!!popupLayer.popupObject);
            tryCompare(popupLayer.popupObject, "opened", true);
            compare(popupLayer.popupObject.maximumHeightOverride, Math.floor(controlUnderTest.height * 0.8));
            verify(popupLayer.popupObject.height <= Math.floor(controlUnderTest.height * 0.8));
        }

        function test_internal_adaptive_dialog_component_is_created_lazily_and_capped() {
            controlUnderTest.internalPopupComponent = internalAdaptiveDialogComponent;
            controlUnderTest.open();
            tryCompare(controlUnderTest, "opened", true);

            const hiddenPopupLayer = findChild(controlUnderTest.Overlay.overlay, "statusAdaptiveDialogInternalPopupLayer");
            verify(!hiddenPopupLayer || !hiddenPopupLayer.visible);
            verify(!hiddenPopupLayer || !hiddenPopupLayer.popupObject);

            controlUnderTest.openInternalPopup();

            const popupLayer = findInternalPopupLayer();
            verify(!!popupLayer.popupObject);
            compare(popupLayer.popupObject.objectName, "internalAdaptiveDialog");
            tryCompare(popupLayer.popupObject, "opened", true);
            compare(popupLayer.popupObject.maximumWidthOverride, controlUnderTest.width);
            compare(popupLayer.popupObject.width, controlUnderTest.width);
            compare(popupLayer.popupObject.maximumHeightOverride, Math.floor(controlUnderTest.height * 0.8));
            verify(popupLayer.popupObject.height <= Math.floor(controlUnderTest.height * 0.8));
            compare(popupLayer.popupObject.x, 0);
            compare(popupLayer.popupObject.y, controlUnderTest.height - popupLayer.popupObject.height);
        }

        function test_internal_adaptive_dialog_tracks_parent_geometry_after_resize() {
            controlUnderTest.destroy();
            controlUnderTest = createTemporaryObject(adaptiveWidthDialogComponent, testWindow.contentItem);
            controlUnderTest.internalPopupComponent = internalAdaptiveDialogComponent;
            controlUnderTest.open();
            tryCompare(controlUnderTest, "opened", true);

            controlUnderTest.openInternalPopup();

            const popupLayer = findInternalPopupLayer();
            const overlay = findInternalOverlay();
            verify(!!popupLayer.popupObject);
            tryCompare(popupLayer.popupObject, "opened", true);

            setTestWindowSize(d.mobileWindowWidth, d.mobileWindowHeight);

            tryCompare(controlUnderTest, "width", d.mobileWindowWidth);
            tryCompare(controlUnderTest, "x", 0);
            verifyInternalLayerMatchesParent(popupLayer, overlay);
            verifyInternalDialogBottomAligned(popupLayer);
        }

        function test_internal_adaptive_dialog_tracks_parent_geometry_from_mobile_to_desktop() {
            setTestWindowSize(d.mobileWindowWidth, d.mobileWindowHeight);
            controlUnderTest.destroy();
            controlUnderTest = createTemporaryObject(adaptiveWidthDialogComponent, testWindow.contentItem);
            controlUnderTest.internalPopupComponent = internalAdaptiveDialogComponent;
            controlUnderTest.open();
            tryCompare(controlUnderTest, "opened", true);

            controlUnderTest.openInternalPopup();

            const popupLayer = findInternalPopupLayer();
            const overlay = findInternalOverlay();
            tryCompare(popupLayer.popupObject, "opened", true);

            setTestWindowSize(d.desktopWindowWidth, d.desktopWindowHeight);

            tryCompare(controlUnderTest, "width", 560);
            tryVerify(() => controlUnderTest.x > 0);
            verifyInternalLayerMatchesParent(popupLayer, overlay);
            verifyInternalDialogBottomAligned(popupLayer);
        }

        function test_bottom_sheet_on_mobile() {
            setTestWindowSize(d.mobileWindowWidth, d.mobileWindowHeight);
            controlUnderTest.destroy();
            controlUnderTest = createTemporaryObject(adaptiveWidthDialogComponent, testWindow.contentItem);

            controlUnderTest.open();
            tryCompare(controlUnderTest, "opened", true);

            compare(controlUnderTest.width, d.mobileWindowWidth);
            compare(controlUnderTest.x, 0);
            verify(controlUnderTest.y >= 0);
        }

        function test_safe_area_is_reserved_in_centered_mode() {
            controlUnderTest.open();
            tryCompare(controlUnderTest, "opened", true);

            setDialogSafeArea(60, 60, 40, 30);
            verifyDialogSafeAreaLayout(60, 60, 40, 30);
        }

        function test_safe_area_is_reserved_in_bottom_sheet_mode() {
            setTestWindowSize(d.mobileWindowWidth, d.mobileWindowHeight);
            controlUnderTest.destroy();
            controlUnderTest = createTemporaryObject(adaptiveWidthDialogComponent, testWindow.contentItem);
            controlUnderTest.open();
            tryCompare(controlUnderTest, "opened", true);

            setDialogSafeArea(60, 60, 40, 30);
            verifyDialogSafeAreaLayout(60, 60, 40, 30);
        }

        function test_modal_can_be_overridden_from_outside() {
            controlUnderTest.destroy();
            controlUnderTest = createTemporaryObject(modalOverrideDialogComponent, testWindow.contentItem);
            controlUnderTest.open();
            tryCompare(controlUnderTest, "opened", true);

            compare(controlUnderTest.modal, false);
        }

        function test_destroy_on_close_destroys_dialog() {
            const marker = createTemporaryQmlObject("import QtQuick; QtObject { property bool wasDestroyed: false }", root);

            controlUnderTest.destroy();
            controlUnderTest = createTemporaryObject(destroyOnCloseDialogComponent, root, {
                "marker": marker
            });
            controlUnderTest.open();
            tryCompare(controlUnderTest, "opened", true);

            controlUnderTest.close();

            tryCompare(marker, "wasDestroyed", true);
            controlUnderTest = null;
        }

        function test_regular_content_uses_internal_scroll_viewport() {
            controlUnderTest.destroy();
            controlUnderTest = createTemporaryObject(tallRegularContentDialogComponent, testWindow.contentItem);
            controlUnderTest.open();
            tryCompare(controlUnderTest, "opened", true);

            const contentViewport = findChild(controlUnderTest, "statusAdaptiveDialogContentViewport");
            const scrollFlickable = findChild(controlUnderTest, "statusAdaptiveDialogScrollFlickable");
            const contentScrollBar = findChild(controlUnderTest, "statusAdaptiveDialogContentScrollBar");
            const headerDivider = findChild(controlUnderTest, "statusAdaptiveDialogHeaderDivider");
            const footerDivider = findChild(controlUnderTest, "statusAdaptiveDialogFooterDivider");
            verify(!!contentViewport);
            verify(!!scrollFlickable);
            verify(!!contentScrollBar);
            verify(!!headerDivider);
            verify(!!footerDivider);
            verify(scrollFlickable.visible);
            verify(scrollFlickable.enabled);
            verify(scrollFlickable.contentHeight > scrollFlickable.height);
            compare(contentViewport.mapToItem(null, 0, 0).y,
                    headerDivider.mapToItem(null, 0, headerDivider.height).y);
            compare(contentViewport.mapToItem(null, 0, contentViewport.height).y,
                    footerDivider.mapToItem(null, 0, 0).y);
            compare(scrollFlickable.topMargin, Math.max(Theme.padding, 8));
            verify(contentScrollBar.x >= contentViewport.x + contentViewport.width);
        }

        function test_content_scrollbar_drag_updates_content_position() {
            controlUnderTest.destroy();
            controlUnderTest = createTemporaryObject(tallRegularContentDialogComponent, testWindow.contentItem);
            controlUnderTest.open();
            tryCompare(controlUnderTest, "opened", true);

            const scrollFlickable = findChild(controlUnderTest, "statusAdaptiveDialogScrollFlickable");
            const contentScrollBar = findChild(controlUnderTest, "statusAdaptiveDialogContentScrollBar");
            verify(!!scrollFlickable);
            verify(!!contentScrollBar);
            verify(contentScrollBar.visible);

            const initialContentY = scrollFlickable.contentY;
            mousePress(contentScrollBar, contentScrollBar.width / 2, 8);
            mouseMove(contentScrollBar, contentScrollBar.width / 2, contentScrollBar.height / 2);
            mouseRelease(contentScrollBar, contentScrollBar.width / 2, contentScrollBar.height / 2);

            verify(scrollFlickable.contentY > initialContentY);
        }

        function test_flickable_content_is_not_wrapped() {
            controlUnderTest.destroy();
            controlUnderTest = createTemporaryObject(flickableContentDialogComponent, testWindow.contentItem);
            controlUnderTest.open();
            tryCompare(controlUnderTest, "opened", true);

            const contentViewport = findChild(controlUnderTest, "statusAdaptiveDialogContentViewport");
            const scrollFlickable = findChild(controlUnderTest, "statusAdaptiveDialogScrollFlickable");
            const flickableContent = findChild(controlUnderTest, "flickableContent");
            verify(!!contentViewport);
            verify(!!scrollFlickable);
            verify(!!flickableContent);
            compare(flickableContent.parent, contentViewport);
            compare(scrollFlickable.visible, false);
            verify(flickableContent.height <= contentViewport.height);
            compare(flickableContent.topMargin, Math.max(Theme.padding, 8));
        }

    }

    Component {
        id: signalSpyComponent

        SignalSpy {}
    }
}
