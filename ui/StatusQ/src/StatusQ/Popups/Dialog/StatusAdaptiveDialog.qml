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
// stay centralized here so individual dialogs do not duplicate geometry rules.
// Content hosting is also resolved by the base dialog: it configures either regular
// content or a Flickable/ListView body and owns the visible scrollbar.
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

    // Dialog body supplied by consumers. The component should describe only the
    // content itself; StatusAdaptiveDialog owns sizing, padding/insets and scroll
    // hosting. Flickable/ListView bodies are detected from the root item or its
    // contentItem. If that body has its own vertical scrollbar, expose it as:
    //   readonly property alias statusAdaptiveDialogContentVerticalScrollBar: <bar>
    // That property describes the loaded root only; the base dialog still owns
    // the vertical scrollbar and contentY/interactive policy.
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
    // Whether the dialog object should destroy itself after it is closed.
    property bool destroyOnClose: false

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

    // Internal bridge used only when another StatusAdaptiveDialog hosts this instance.
    // It stays on root because the parent dialog configures the loaded child instance.
    // Consumers should create/open dialogs normally.
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

        // Safe-area insets for the dialog surface. The dialog reads them from its
        // content host so tests and hosted dialogs can override them locally
        // without changing the whole window.
        readonly property real headerSafeArea: root.contentItem.SafeArea.margins.top
        readonly property real footerSafeArea: root.contentItem.SafeArea.margins.bottom
        readonly property real leftSafeArea: root.contentItem.SafeArea.margins.left
        readonly property real rightSafeArea: root.contentItem.SafeArea.margins.right
        // Vertical padding owned by the content host. When content is the first or
        // last visible section, it also absorbs the corresponding safe area.
        readonly property real contentTopPadding: edgePadding + (hasHeader ? 0 : headerSafeArea)
        readonly property real contentBottomPadding: edgePadding + (hasFooterSection ? 0 : footerSafeArea)
        readonly property real contentLeftPadding: edgePadding + leftSafeArea
        readonly property real contentRightPadding: edgePadding + rightSafeArea

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

        // Bottom sheets always span the full window width.
        readonly property real resolvedBottomSheetWidth: windowWidth
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

    enabled: opened && !enterTransition.running

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
            Layout.topMargin: d.edgePadding + d.headerSafeArea
            Layout.leftMargin: d.edgePadding + d.leftSafeArea
            Layout.rightMargin: d.edgePadding + d.rightSafeArea
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
        leftPadding: d.contentLeftPadding
        rightPadding: d.contentRightPadding
        topPadding: 0
        bottomPadding: 0
        flickableTopPadding: d.contentTopPadding
        flickableBottomPadding: d.contentBottomPadding
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
            Layout.leftMargin: d.edgePadding + d.leftSafeArea
            Layout.rightMargin: d.edgePadding + d.rightSafeArea
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
            Layout.leftMargin: d.edgePadding + d.leftSafeArea
            Layout.rightMargin: d.edgePadding + d.rightSafeArea
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
    onClosed: {
        closeInternalPopup()
        if (root.destroyOnClose)
            root.destroy()
    }

    Item {
        id: internalPopupLayer

        // Hosts a secondary StatusAdaptiveDialog over the current dialog surface.
        // The layer tracks root geometry during normal use, paints the local dimmer,
        // and freezes its bounds for the parent-close frame so both exit animations
        // can complete without the nested dialog jumping back to window coordinates.
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
                onClicked: if (internalPopupLayer.closeOnOverlayClick)
                    root.closeInternalPopup()
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
