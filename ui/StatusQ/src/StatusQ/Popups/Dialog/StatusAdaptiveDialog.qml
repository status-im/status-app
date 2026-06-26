import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQml.Models

import StatusQ.Core.Theme

// Base dialog container that owns presentation, sizing and interaction rules.
//
// The dialog automatically chooses one of two modes:
// - bottom sheet on narrow portrait windows
// - centered dialog on wider or landscape windows
//
// Consumers configure the header data/actions and provide content/footer components.
// Layout decisions such as mode selection, size caps, positioning and overlay behavior
// stay centralized here so individual dialogs do not duplicate geometry rules. Content
// hosting is also resolved by the base dialog: it decides whether to reuse a provided
// Flickable (Strategy A) or wrap regular content in an internal scroll container (Strategy B).
// When Strategy A applies, the dialog owns the scrollbar — the content item must disable any
// built-in scrollbar it carries to avoid duplicates (e.g. StatusListView.ScrollBar.vertical: null).
//
// The dialog can also host one nested StatusAdaptiveDialog inside its own surface.
// This is intended for secondary steps that must dim and cover the current dialog
// header/content/footer without opening a full-window modal. The internal dialog is
// loaded lazily, sized within the parent dialog bounds, and closed automatically with
// the parent dialog.
Dialog {
    id: root

    // Header related properties:
    property alias subtitle: headerToolbarItem.subtitle
    property alias leftHeaderComponent: headerToolbarItem.leftComponent
    readonly property alias headerActions: headerToolbarItem.actions
    property alias headerCustomButtons: headerToolbarItem.actions.customButtons

    property Component contentComponent

    // Footer related properties:
    property ObjectModel footerLeftButtons
    property ObjectModel footerRightButtons
    property ObjectModel errorTags

    // StatusAdaptiveDialog component used by openInternalPopup(). It is configured
    // as a modeless child of the parent dialog's internal popup layer.
    property Component internalPopupComponent
    // Color used by the internal overlay that covers the parent dialog while the
    // internal popup is active.
    property color internalOverlayColor: Theme.palette.backdropColor
    // Whether the internal dialog layer is currently open. It may be hidden for a
    // parent-close frame while still finishing the nested dialog lifecycle.
    readonly property bool internalPopupActive: internalPopupLayer.active

    // Whether pressing outside the dialog closes it.
    property bool closeOnOverlayClick: true
    // Whether pressing Escape closes the dialog.
    property bool escapeKeyCloses: !d.bottomSheet

    // Exceptional override. Leave 0 to let the dialog resolve its own width.
    property int maximumWidthOverride: 0
    // Exceptional override. Leave 0 to let the dialog resolve its own height.
    property int maximumHeightOverride: 0
    // Whether to show the divider between the header toolbar and content.
    property bool showHeaderDivider: true
    // Whether to show the divider between the content and footer.
    property bool showFooterDivider: true

    function openInternalPopup() {
        internalPopupLayer.open()
    }

    function closeInternalPopup() {
        internalPopupLayer.close()
    }

    // Internal: used when this dialog is hosted as another StatusAdaptiveDialog's
    // internal dialog. Consumers should create/open dialogs normally.
    function setHostSurface(surface) {
        d.hostSurface = surface
    }

    QtObject {
        id: d

        property Item hostSurface: null

        // NB: must be set in onAboutToShow, not declaratively — contentItem.Window.width/height
        // is 0 before the popup is attached to a window (the attached property always exists
        // but carries no dimensions until then).
        property int windowWidth: Screen.width
        property int windowHeight: Screen.height

        readonly property bool hasHeader: !!root.title || !!root.subtitle
        readonly property bool hasContent: !!root.contentComponent
        readonly property bool hasFooter: !!root.footerLeftButtons || !!root.footerRightButtons
        readonly property bool hasErrorTags: !!root.errorTags
        // Footer section is visible when either action buttons or error tags are present.
        // The bottom safe area is applied to whichever visible section sits at the sheet bottom.
        readonly property bool hasFooterSection: hasFooter || hasErrorTags
        readonly property real headerHeight: headerSection.implicitHeight
        readonly property real footerHeight: footerSection.implicitHeight

        // Internal spacing between the dialog edge and each visible component.
        readonly property real edgePadding: Math.max(root.Theme.padding, 8)

        readonly property bool bottomSheet: windowWidth <= ThemeUtils.portraitBreakpoint.width
                                            && windowHeight > windowWidth

        // Safe-area insets for bottom-sheet mode, read from the Window so the values
        // are stable physical constants rather than position-dependent computed values.
        readonly property real headerSafeArea: bottomSheet
            ? (root.contentItem.Window.window?.SafeArea.margins.top ?? 0) : 0
        readonly property real footerSafeArea: bottomSheet
            ? (root.contentItem.Window.window?.SafeArea.margins.bottom ?? 0) : 0
        // Vertical padding owned by the content host. When the content is the last visible
        // section in a bottom sheet, bottom padding also absorbs the home-indicator safe area.
        readonly property real contentTopPadding: edgePadding
        readonly property real contentBottomPadding: edgePadding + (bottomSheet && !hasFooterSection ? footerSafeArea : 0)

        // Internal max width for centered dialogs.
        readonly property real centeredMaxWidth: 560
        // Centered dialogs can use up to this fraction of the window height.
        readonly property real centeredHeightRatio: 0.8
        // Total horizontal space reserved around centered dialogs.
        readonly property real centeredHorizontalMargin: 2 * Theme.bigPadding
        // Width used by centered dialogs after applying margins and the exceptional override, if any.
        readonly property real resolvedCenteredWidth: Math.min(root.maximumWidthOverride > 0 ? root.maximumWidthOverride : centeredMaxWidth,
                                                               Math.max(root.implicitWidth, windowWidth - centeredHorizontalMargin))
        // Height cap used by centered dialogs after applying the exceptional override, if any.
        readonly property real resolvedCenteredMaxHeight: root.maximumHeightOverride > 0 ? Math.min(root.maximumHeightOverride, windowHeight)
                                                                                         : windowHeight * centeredHeightRatio

        // Width used by bottom sheets after applying the exceptional override, if any.
        readonly property real resolvedBottomSheetWidth: root.maximumWidthOverride > 0 ? Math.min(root.maximumWidthOverride, windowWidth)
                                                                                       : windowWidth
        // Bottom sheets can use up to this fraction of the window height.
        readonly property real bottomSheetHeightRatio: 0.9
        // Height cap for bottom sheets. The ratio is applied to the usable height
        // (window minus top safe area) so the visible gap above the dialog is
        // consistent regardless of notch/status-bar size. footerSafeArea is then
        // added back so the home-indicator padding does not reduce the content area.
        readonly property real resolvedBottomSheetMaxHeight: (root.maximumHeightOverride > 0
            ? Math.min(root.maximumHeightOverride, windowHeight)
            : (windowHeight - headerSafeArea) * bottomSheetHeightRatio) + footerSafeArea

        // Height ratio selected by the active presentation mode. Reused by internal
        // popup hosting so nested surfaces follow the same cap as their parent mode.
        readonly property real resolvedHeightRatio: bottomSheet ? bottomSheetHeightRatio : centeredHeightRatio
        // Final width after choosing the presentation mode.
        readonly property real resolvedWidth: bottomSheet ? resolvedBottomSheetWidth : resolvedCenteredWidth
        // Final height cap after choosing the presentation mode.
        readonly property real resolvedMaxHeight: bottomSheet ? resolvedBottomSheetMaxHeight : resolvedCenteredMaxHeight
        // Natural dialog height before cap: fixed header + content natural height + fixed footer.
        readonly property real naturalHeight: headerHeight
                                              + contentHost.implicitHeight
                                              + footerHeight
        // Final vertical position: anchored to bottom of host surface, window bottom for sheets, centered otherwise.
        // Note: for hosted dialogs the parent is internalPopupLayer, so y is in its local coordinate space.
        readonly property real resolvedY: hostSurface
            ? hostSurface.height - root.height
            : bottomSheet ? windowHeight - root.height
                          : (windowHeight - root.height) / 2
        // Make the loaded component root follow the area owned by the dialog layout.
        function bindLoadedItemToContentArea(item, contentArea) {
            if (!item)
                return;

            item.width = Qt.binding(() => contentArea.width);
            item.height = Qt.binding(() => contentArea.height);
        }
    }

    parent: Overlay.overlay
    modal: true
    padding: 0
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0
    spacing: 0
    // TODO: Verify if bottom sheets still need the legacy -1 margin adjustment.
    margins: d.bottomSheet ? -1 : 0
    closePolicy: (root.escapeKeyCloses ? Popup.CloseOnEscape : Popup.NoAutoClose)
                 | (root.closeOnOverlayClick ? Popup.CloseOnPressOutside : Popup.NoAutoClose)

    Overlay.modal: overlayBackgroundComponent
    Overlay.modeless: overlayBackgroundComponent

    width: d.resolvedWidth
    height: Math.min(d.naturalHeight, d.resolvedMaxHeight)

    x: d.hostSurface ? 0
                     : d.bottomSheet ? 0 : (d.windowWidth - root.width) / 2

    enter: Transition {
        id: enterTransition

        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: ThemeUtils.AnimationDuration.Fast
            }
            NumberAnimation {
                property: "y"
                from: d.hostSurface ? d.hostSurface.height
                                    : (root.parent ? root.parent.height : d.windowHeight)
                to: d.resolvedY
                duration: ThemeUtils.AnimationDuration.Fast
                easing.type: Easing.OutCubic
            }
        }
    }

    exit: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: ThemeUtils.AnimationDuration.Fast
                easing.type: Easing.OutQuint
            }
            NumberAnimation {
                property: "y"
                from: root.y
                to: d.hostSurface ? d.hostSurface.height
                                  : (root.parent ? root.parent.height : d.windowHeight)
                duration: ThemeUtils.AnimationDuration.Fast
                easing.type: Easing.OutCubic
            }
        }
    }

    background: StatusDialogBackground {}

    // Header contract:
    // - Uses Dialog.header so the native Dialog layout owns section placement.
    // - The toolbar receives top/horizontal edge padding; the divider is full width.
    // - Consumers configure data/actions through the dialog API, not by replacing
    //   the internal toolbar.
    header: ColumnLayout {
        id: headerSection

        visible: root.visible
        spacing: d.edgePadding

        StatusAdaptiveDialogHeader {
            id: headerToolbarItem

            Layout.fillWidth: true
            Layout.topMargin: d.edgePadding
            Layout.leftMargin: d.edgePadding
            Layout.rightMargin: d.edgePadding
            visible: d.hasHeader
            title: root.title
            actions.closeButton.onClicked: mouse => root.close()
        }

        StatusDialogDivider {
            id: headerDivider

            objectName: "statusAdaptiveDialogHeaderDivider"
            Layout.fillWidth: true
            visible: root.showHeaderDivider && d.hasHeader && d.hasContent
        }
    }

    contentItem: StatusAdaptiveDialogContentHost {
        id: contentHost

        implicitHeight: visible ? naturalHeight + d.contentTopPadding + d.contentBottomPadding : 0
        visible: root.visible && d.hasContent
        contentComponent: root.contentComponent
        contentMargin: d.edgePadding
        contentTopMargin: d.contentTopPadding
        contentBottomMargin: d.contentBottomPadding
    }

    // Footer contract:
    // - Uses Dialog.footer so the native Dialog layout owns section placement.
    // - The divider is full width; error tags and toolbar content receive edge padding.
    // - Consumers provide button/error models while the dialog owns footer layout.
    footer: ColumnLayout {
        id: footerSection

        visible: root.visible && d.hasFooterSection
        spacing: 0

        StatusDialogDivider {
            objectName: "statusAdaptiveDialogFooterDivider"
            Layout.fillWidth: true
            visible: root.showFooterDivider && d.hasContent
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: d.hasErrorTags ? d.edgePadding : 0
            Layout.bottomMargin: d.hasFooter ? 0 : d.edgePadding + d.footerSafeArea
            Layout.leftMargin: d.edgePadding
            Layout.rightMargin: d.edgePadding
            spacing: Math.max(Theme.halfPadding, 8)
            visible: d.hasErrorTags

            Repeater {
                model: root.errorTags
                onItemAdded: (_, item) => item.Layout.fillWidth = true
            }
        }

        StatusAdaptiveDialogFooter {
            id: footerToolbarItem

            Layout.fillWidth: true
            Layout.topMargin: d.hasErrorTags ? Math.max(Theme.halfPadding, 8) : d.edgePadding
            Layout.bottomMargin: d.edgePadding + d.footerSafeArea
            Layout.leftMargin: d.edgePadding
            Layout.rightMargin: d.edgePadding
            visible: d.hasFooter

            leftButtons: root.footerLeftButtons
            rightButtons: root.footerRightButtons
        }
    }

    onAboutToShow: {
        d.windowWidth = Qt.binding(() => root.contentItem.Window ? root.contentItem.Window.width : Screen.width)
        d.windowHeight = Qt.binding(() => root.contentItem.Window ? root.contentItem.Window.height : Screen.height)
    }

    onAboutToHide: internalPopupLayer.hideDuringParentClose()
    onClosed: closeInternalPopup()

    Item {
        id: internalPopupLayer

        objectName: "statusAdaptiveDialogInternalPopupLayer"
        parent: null
        x: hiddenDuringParentClose ? frozenX : root.x
        y: hiddenDuringParentClose ? frozenY : root.y
        z: root.z + 1
        width: hiddenDuringParentClose ? frozenWidth : root.width
        height: hiddenDuringParentClose ? frozenHeight : root.height
        visible: active && !hiddenDuringParentClose
        enabled: visible

        property bool active: false
        property bool hiddenDuringParentClose: false
        readonly property var popupObject: popupLoader.item
        readonly property bool hasPopupObject: !!popupObject
        property bool closeOnOverlayClick: true
        // Snapshot used only while the parent dialog is closing. During normal
        // operation the layer follows root geometry so resize/orientation changes
        // propagate to the internal dialog.
        property real frozenX: root.x
        property real frozenY: root.y
        property real frozenWidth: root.width
        property real frozenHeight: root.height
        readonly property real maximumPopupHeightRatio: d.resolvedHeightRatio
        readonly property int maximumPopupHeight: Math.floor(height * maximumPopupHeightRatio)

        function open() {
            if (!root.internalPopupComponent)
                return;

            parent = root.Overlay.overlay;
            hiddenDuringParentClose = false;
            closeOnOverlayClick = true;
            active = true;
        }

        function close() {
            if (popupObject && popupObject.opened) {
                popupObject.close();
                return;
            }

            deactivate();
        }

        function deactivate() {
            active = false;
            hiddenDuringParentClose = false;
            closeOnOverlayClick = true;
            parent = null;
        }

        function hideDuringParentClose() {
            frozenX = root.x;
            frozenY = root.y;
            frozenWidth = root.width;
            frozenHeight = root.height;
            hiddenDuringParentClose = true;
        }

        function configurePopupObject(dialog) {
            if (!dialog)
                return;

            dialog.parent = internalPopupLayer;
            internalPopupLayer.closeOnOverlayClick = dialog.closeOnOverlayClick;
            dialog.closeOnOverlayClick = false;
            dialog.setHostSurface(internalPopupLayer);
            dialog.open();
        }

        Binding {
            target: internalPopupLayer.popupObject
            property: "modal"
            value: false
            when: internalPopupLayer.hasPopupObject
        }

        Binding {
            target: internalPopupLayer.popupObject
            property: "dim"
            value: false
            when: internalPopupLayer.hasPopupObject
        }

        Binding {
            target: internalPopupLayer.popupObject
            property: "z"
            value: internalPopupLayer.z + 1
            when: internalPopupLayer.hasPopupObject
        }

        Binding {
            target: internalPopupLayer.popupObject
            property: "maximumWidthOverride"
            value: internalPopupLayer.width
            when: internalPopupLayer.hasPopupObject
        }

        Binding {
            target: internalPopupLayer.popupObject
            property: "maximumHeightOverride"
            value: internalPopupLayer.maximumPopupHeight
            when: internalPopupLayer.hasPopupObject
        }

        Loader {
            id: popupLoader

            active: internalPopupLayer.active
            sourceComponent: internalPopupLayer.active ? root.internalPopupComponent : null
            onLoaded: internalPopupLayer.configurePopupObject(item)
        }

        Connections {
            target: internalPopupLayer.popupObject
            function onClosed() {
                internalPopupLayer.deactivate()
            }
        }

        Rectangle {
            id: internalOverlay

            objectName: "statusAdaptiveDialogInternalOverlay"
            anchors.fill: parent
            radius: d.bottomSheet ? 0 : Theme.radius
            color: root.internalOverlayColor

            MouseArea {
                anchors.fill: parent
                anchors.bottomMargin: internalPopupLayer.popupObject ? internalPopupLayer.popupObject.height : 0
                onClicked: if (internalPopupLayer.closeOnOverlayClick) root.closeInternalPopup()
            }
        }
    }

    Binding on y {
        when: !enterTransition.running
        value: d.resolvedY
    }

    Component {
        id: overlayBackgroundComponent

        Rectangle {
            color: Theme.palette.backdropColor
        }
    }
}
