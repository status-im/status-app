import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls

import mainui

import shared.controls

import AppLayouts.Profile.helpers

import utils

Control {
    id: root

    /**
      Expected model structure

        id                  [string] - unique id of the section
        sectionType         [int]    - type of this section (Constants.appSection.*)
        name                [string] - section's name, e.g. "Chat" or "Wallet" or a community name
        icon                [string] - section's icon (url like or blob)
        color               [color]  - the section's color
        banner              [string] - the section's banner image (url like or blob), mostly empty for non-communities
        hasNotification     [bool]   - whether the section has any notification (w/o denoting the number)
        notificationsCount  [int]    - number of notifications, if any
        enabled             [bool]   - whether the section should show in the UI
        active              [bool]   - whether the section is currently active
    **/
    required property var regularItemsModel
    required property var communityItemsModel
    required property var bottomItemsModel

    // defaults to true in landscape (desktop/tablet) mode; can be overridden here
    property bool alwaysVisible: d.windowWidth > d.windowHeight

    required property ContactDetails selfContactDetails
    // External swipe/drag driver can set this directly (0..1).
    // When alwaysVisible is true, we force it to 1.
    property real position: 0.0
    readonly property bool opened: alwaysVisible || position >= 0.999
    // Used by button delegates to auto-close on click in non-always-visible mode.
    readonly property bool interactive: !alwaysVisible && !d.hasPopups
    property var getLinkToProfileFn: function(pubkey) { console.error("IMPLEMENT ME"); return "" }
    property var getEmojiHashFn: function(pubkey) { console.error("IMPLEMENT ME"); return "" }

    property Component communityPopupMenu // required property var model

    required property bool profileSectionHasNotification
    required property bool showCreateCommunityBadge
    required property bool thirdpartyServicesEnabled

    required property bool acVisible // FIXME AC should not be a section
    required property bool acHasUnseenNotifications // ActivityCenterStore.hasUnseenNotifications
    required property int acUnreadNotificationsCount // ActivityCenterStore.unreadNotificationsCount

    signal itemActivated(int sectionType, string sectionId)
    signal activityCenterRequested(bool shouldShow)
    signal viewProfileRequested(string pubKey)
    signal setCurrentUserStatusRequested(int status)

    Component.onCompleted: d.snapToMode()
    onAlwaysVisibleChanged: d.snapToMode()

    // Slide in/out from the left.
    x: alwaysVisible ? 0 : (-width + width * position)

    // Animate snapping when not directly driven by a drag/swipe.
    Behavior on position {
        enabled: !d.dragActive && !root.alwaysVisible
        NumberAnimation {
            duration: ThemeUtils.AnimationDuration.Fast
            easing.type: Easing.OutCubic
        }
    }

    function open() { d.dragActive = false; position = 1.0 }
    function close() { if (root.alwaysVisible) return; d.dragActive = false; position = 0.0 } 
    function toggle() { root.position == 0.0 ? open() : close() }


    // Padding and spacing were previously Drawer properties; keep them as locals.
    topPadding: parent.SafeArea.margins.top + Theme.defaultHalfPadding
    bottomPadding: parent.SafeArea.margins.bottom + Theme.defaultHalfPadding
    leftPadding: parent.SafeArea.margins.left + Theme.defaultHalfPadding
    rightPadding: 0
    spacing: Theme.defaultHalfPadding

    implicitWidth: 60 + leftPadding

    QtObject {
        id: d

        // UI
        readonly property int windowWidth: root.parent?.Window?.width ?? Screen.width
        readonly property int windowHeight: root.parent?.Window?.height ?? Screen.height

        readonly property color containerBgColor: root.thirdpartyServicesEnabled ? root.Theme.palette.statusAppNavBar.backgroundColor
                                                                                 : root.Theme.palette.privacyColors.primary
        readonly property int containerBgRadius: Theme.defaultPadding

        readonly property bool hasPopups: root.Overlay.overlay.children.filter(item => item.toString().includes("QQuickPopupItem") && item.toString().includes("StatusTooltip")).length

        onHasPopupsChanged: {
            if (d.hasPopups) {
                root.close()
            }
        }

        // context menu guard
        property var popupMenuInstance: null
        readonly property var _conn: Connections {
            target: d.popupMenuInstance ?? null
            function onClosed() {
                d.popupMenuInstance.destroy()
                d.popupMenuInstance = null
            }
        }

        // When true, disable snapping animation so the drawer tracks the finger precisely.
        property bool dragActive: false
        // Snap when switching between modes:
        // - alwaysVisible=true  -> force open immediately (position=1)
        // - alwaysVisible=false -> default closed (position=0)
        function snapToMode() {
            d.dragActive = false
            root.position = root.alwaysVisible ? 1.0 : 0.0
        }
    }

    // Tap outside the sidebar to close it
    Item {
        parent: Window.window?.contentItem
        readonly property point sidebarTopLeft: parent?.mapFromItem(root, 0, 0) ?? Qt.point(0, 0)
        readonly property point sidebarBottomRight: parent?.mapFromItem(root, root.width * root.position, root.height) ?? Qt.point(0, 0)
        height: parent?.height ?? 0
        x: Math.max(0, sidebarBottomRight.x)
        width: Math.max(0, (parent?.width ?? 0) - x)
        TapHandler {
            enabled: !root.alwaysVisible && root.position > 0.5
            onPressedChanged: root.close()
        }
    }

    // Swipe-to-close inside the drawer (when not alwaysVisible).
    // Use DragHandler so it behaves consistently regardless of the initial open/closed state.
    DragHandler {
        id: closeDrag
        enabled: !root.alwaysVisible && root.position > 0
        xAxis.enabled: true
        yAxis.enabled: false
        // Don't target anything, we don't want to capture the drag
        target: null

        property real _startPos: 0
        property real _lastTx: 0
        property real _lastDelta: 0

        onActiveChanged: {
            if (active) {
                d.dragActive = true
                _startPos = root.position
                _lastTx = translation.x
                _lastDelta = 0
            } else {
                const opening =
                    _lastDelta > 0 ? true :
                    _lastDelta < 0 ? false :
                    root.position >= 0.5

                d.dragActive = false
                root.position = opening ? 1.0 : 0.0
                opening ? root.open() : root.close()
            }
        }

        onTranslationChanged: {
            const dx = translation.x - _lastTx
            _lastDelta = dx
            _lastTx = translation.x

            const nextPos = _startPos + (translation.x / Math.max(1.0, root.width))
            root.position = Math.max(0.0, Math.min(1.0, nextPos))
        }
    }

    contentItem: ColumnLayout {
        spacing: root.spacing

        // main section
        Control {
            objectName: "primaryNavSideBarControl"

            Layout.fillWidth: true
            Layout.fillHeight: true
            topPadding: Theme.defaultSmallPadding
            bottomPadding: Theme.defaultSmallPadding

            background: Rectangle {
                color: d.containerBgColor
                radius: d.containerBgRadius
            }

            contentItem: ColumnLayout {
                // regular sections
                SidebarListView {
                    Layout.fillHeight: true
                    Layout.maximumHeight: contentHeight
                    model: root.regularItemsModel
                    delegate: RegularSectionButton {}
                }

                // separator
                SidebarSeparator {}

                // communities
                SidebarListView {
                    Layout.fillHeight: true
                    model: root.communityItemsModel
                    delegate: CommunitySectionButton {}
                }

                // separator
                SidebarSeparator {}

                // settings + community portal
                SidebarListView {
                    Layout.preferredHeight: contentHeight
                    model: root.bottomItemsModel
                    delegate: BottomSectionButton {}
                }

                // own profile
                ProfileButton {
                    objectName: "statusProfileNavBarTabButton"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: root.spacing
                    name: root.selfContactDetails.displayName
                    pubKey: root.selfContactDetails.publicKey
                    compressedPubKey: root.selfContactDetails.compressedPubKey
                    iconSource: root.selfContactDetails.icon
                    colorId: root.selfContactDetails.colorId
                    currentUserStatus: root.selfContactDetails.onlineStatus
                    usesDefaultName: root.selfContactDetails.usesDefaultName

                    getEmojiHashFn: root.getEmojiHashFn
                    getLinkToProfileFn: root.getLinkToProfileFn

                    onSetCurrentUserStatusRequested: (status) => root.setCurrentUserStatusRequested(status)
                    onViewProfileRequested: (pubKey) => root.viewProfileRequested(pubKey)
                }
            }
        }

        // AC button
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: width

            // prevent opacity multiplying; root has a "transparent" background!
            color: d.containerBgColor
            radius: d.containerBgRadius

            PrimaryNavSidebarButton {
                id: acButton
                anchors.fill: parent
                bgRadius: parent.radius

                objectName: "Activity Center-navbar"

                checkable: true
                checked: root.acVisible

                icon.name: "notification"

                showBadge: root.acHasUnseenNotifications || root.acUnreadNotificationsCount
                badgeCount: root.acUnreadNotificationsCount

                thirdpartyServicesEnabled: root.thirdpartyServicesEnabled

                onToggled: {
                    root.activityCenterRequested(checked)
                    root.close()
                }
            }
        }
    }

    component RegularSectionButton: PrimaryNavSidebarButton {
        objectName: model.name + "-navbar"
        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined

        tooltipText: Utils.translatedSectionName(model.sectionType)
        checked: model.active
        icon.name: model.icon
        icon.source: model.image
        text: model.icon.length > 0 ? "" : model.name

        showBadge: model.hasNotification
        badgeCount: model.notificationsCount

        thirdpartyServicesEnabled: root.thirdpartyServicesEnabled

        onClicked: {
            print ("!!!! Clicked", model.name)
            d.popupMenuInstance?.close()
            root.itemActivated(model.sectionType, model.id)
            if (root.interactive)
                root.close()
        }
    }

    component CommunitySectionButton: RegularSectionButton {
        id: communityNavBarButton
        objectName: "CommunityNavBarButton"

        tooltipText: model.name

        // different bg with a border instead of solid bg color when checked
        background: Rectangle {
            color: {
                if (!communityNavBarButton.thirdpartyServicesEnabled) {
                    if (communityNavBarButton.hovered || communityNavBarButton.highlighted)
                        return StatusColors.alphaColor(StatusColors.white, 0.25)
                }

                if (communityNavBarButton.hovered || communityNavBarButton.highlighted)
                    return Theme.palette.primaryColor2

                return Theme.palette.transparent
            }

            border.width: 2
            border.color: communityNavBarButton.checked ? Theme.palette.primaryColor1 : Theme.palette.transparent

            radius: communityNavBarButton.bgRadius
        }

        // context menu
        function openCommunityContextMenu(x, y) {
            if (!root.communityPopupMenu)
                return

            if (!!d.popupMenuInstance)
                d.popupMenuInstance.close() // will run destruction/cleanup

            d.popupMenuInstance = root.communityPopupMenu.createObject(this, {model})
            this.highlighted = Qt.binding(() => !!d.popupMenuInstance && d.popupMenuInstance.opened && d.popupMenuInstance.parent === this)
            d.popupMenuInstance.popup(this, x, y)
        }
        onContextMenuRequested: (x, y) => openCommunityContextMenu(x, y)

        // "banned" decoration
        StatusRoundIcon {
            visible: model.amIBanned
            width: 16
            height: width
            anchors.top: parent.top
            anchors.left: parent.right
            anchors.leftMargin: -width

            color: Theme.palette.dangerColor1
            border.color: d.containerBgColor
            border.width: 2
            asset.name: "cancel"
            asset.color: d.containerBgColor
            asset.width: 10
        }

        Binding on icon.color {
            value: model.color
            when: !highlighted || !down || !checked
        }
    }

    component BottomSectionButton: RegularSectionButton {
        readonly property bool displayCreateCommunityBadge: model.sectionType === Constants.appSection.communitiesPortal && root.showCreateCommunityBadge
        showBadgeGradient: displayCreateCommunityBadge
        showBadge: {
            if (model.sectionType === Constants.appSection.profile)
                return root.profileSectionHasNotification
            if (displayCreateCommunityBadge)
                return true
            return model.hasNotification
        }
    }

    component SidebarListView: ListView {
        id: sidebarLV

        Layout.fillWidth: true
        clip: true
        spacing: root.spacing
        interactive: contentHeight > height

        layer.enabled: true
        layer.effect: MultiEffect {
            source: sidebarLV
            maskEnabled: true
            maskSource: gradientMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        // Mask geometry
        Rectangle {
            id: gradientMask
            anchors.fill: sidebarLV
            visible: false
            layer.enabled: true
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop {position: 0; color: !sidebarLV.atYBeginning ? Qt.rgba(1, 1, 1, 0) : Qt.rgba(0, 0, 0)}
                GradientStop {position: 0.1; color: Qt.rgba(0, 0, 0)}
                GradientStop {position: 0.9; color: Qt.rgba(0, 0, 0)}
                GradientStop {position: 1; color: !sidebarLV.atYEnd ? Qt.rgba(1, 1, 1, 0) : Qt.rgba(0, 0, 0)}
            }
        }
    }

    component SidebarSeparator: Rectangle {
        Layout.preferredWidth: Theme.defaultPadding
        Layout.preferredHeight: 1
        Layout.alignment: Qt.AlignHCenter
        color: Theme.palette.baseColor1
    }

        // Component that provides clipping for the indicator
    Item {
        id: swipeIndicatorWrapper
        anchors.left: root.right
        anchors.verticalCenter: root.verticalCenter
        anchors.verticalCenterOffset: Math.min((root.height - height) * 0.5, root.height * 0.25)
        // position the indicator closer to the natural position of the thumb
        width: 5
        height: 100
        // Clip the indicator to create a hiding below the navbar effect
        clip: true
        visible: root.interactive

        NativeIndicator {
            width: swipeIndicatorWrapper.width
            height: swipeIndicatorWrapper.height
            x: - width * root.position
            source: Assets.svg("swipe-indicator")
        }
    }

    // Swipe gesture handler for sidebar (native on iOS/Android/macOS)
    // Must be OUTSIDE the sidebar so it can catch gestures when the sidebar is closed.
    NativeSwipeHandler {
        id: navSwipeHandler
        anchors.verticalCenter: swipeIndicatorWrapper.verticalCenter
        width: 2 * root.width
        // Max 200px is allowed on Android
        height: swipeIndicatorWrapper.height * 2
        openDistance: root.width
        enabled: root.interactive
        visible: enabled

        property real _startPos: 0

        onSwipeStarted: () => {
            d.dragActive = true
            _startPos = root.position
        }
        onSwipeUpdated: (delta, velocity) => {
            const pos = _startPos + (delta / Math.max(1.0, root.width))
            root.position = Math.max(0.0, Math.min(1.0, pos))
        }
        onSwipeEnded: (delta, velocity, canceled) => {
            if (canceled) {
                d.dragActive = false
                return
            }
            const opening =
                velocity > ThemeUtils.AnimationDuration.Default ? true :
                velocity < -ThemeUtils.AnimationDuration.Default ? false :
                root.position >= 0.5

            d.dragActive = false
            opening ? root.open() : root.close()
        }
    }
}
