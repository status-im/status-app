import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Theme
import StatusQ.Components

import mainui

import shared.controls

import AppLayouts.Profile.helpers

import utils

Drawer {
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

    edge: Qt.LeftEdge

    // behaviors like visible/modal/interactive/dim all depend on `alwaysVisible`
    visible: alwaysVisible
    interactive: !alwaysVisible
    dim: !alwaysVisible
    modal: false // otherwise the handle blocks input

    topPadding: Qt.platform.os === SQUtils.Utils.mac && Window.visibility !== Window.FullScreen ? 48
                                                                                                : 8
    bottomPadding: 8
    leftPadding: 8
    rightPadding: 0

    spacing: 8

    background: Rectangle {
        color: Theme.palette.transparent
    }

    implicitWidth: 68 // by design (60 + leftPadding + handle)

    QtObject {
        id: d

        // UI
        readonly property int windowWidth: root.parent?.Window?.width ?? Screen.width
        readonly property int windowHeight: root.parent?.Window?.height ?? Screen.height

        readonly property color containerBgColor: root.thirdpartyServicesEnabled ? root.Theme.palette.statusAppNavBar.backgroundColor
                                                                                 : root.Theme.palette.privacyColors.primary
        readonly property int containerBgRadius: 16

        // context menu guard
        property var popupMenuInstance: null
        readonly property var _conn: Connections {
            target: d.popupMenuInstance ?? null
            function onClosed() {
                d.popupMenuInstance.destroy()
                d.popupMenuInstance = null
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: root.spacing

        // main section
        Control {
            objectName: "primaryNavSideBarControl"

            Layout.fillWidth: true
            Layout.fillHeight: true
            topPadding: 10
            bottomPadding: 10

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

                showBadge: root.acHasUnseenNotifications
                badgeCount: root.acUnreadNotificationsCount

                thirdpartyServicesEnabled: root.thirdpartyServicesEnabled

                onToggled: root.activityCenterRequested(checked)
            }
        }
    }

    // "rainbow" handle
    // (parented to the Overlay, so that it functionally stays on top of the drawer,
    // but visually sticking out from under, even when collapsed/invisible)
    Rectangle {
        objectName: "rainbowHandle"
        height: 100
        width: 16
        radius: width
        parent: root.Overlay.overlay
        anchors.left: parent.left
        anchors.leftMargin: (root.width * root.position) - width/2
        anchors.verticalCenter: parent.verticalCenter
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop {position: 0; color: "#7552FA"}
            GradientStop {position: 0.2; color: "#6D9C9F"}
            GradientStop {position: 0.4; color: "#F1AF40"}
            GradientStop {position: 0.6; color: "#F7A440"}
            GradientStop {position: 0.8; color: "#F87A4F"}
        }
        visible: root.position < 1
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
        Layout.preferredWidth: 16
        Layout.preferredHeight: 1
        Layout.alignment: Qt.AlignHCenter
        color: Theme.palette.baseColor1
    }
}
