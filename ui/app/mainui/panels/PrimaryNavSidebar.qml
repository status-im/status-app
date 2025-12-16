import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Theme
import StatusQ.Components

import mainui

import shared.controls

import AppLayouts.Profile.stores as ProfileStores

import utils

import SortFilterProxyModel

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
    required property var sectionsModel

    // defaults to true in landscape (desktop/tablet) mode; can be overridden here
    property bool alwaysVisible: d.windowWidth > d.windowHeight

    required property ProfileStores.ProfileStore profileStore
    property var getLinkToProfileFn: function(pubkey) { console.error("IMPLEMENT ME"); return "" }
    property var getEmojiHashFn: function(pubkey) { console.error("IMPLEMENT ME"); return "" }

    property Component communityPopupMenu

    property bool showEnabledSectionsOnly: true

    required property bool marketEnabled
    required property bool browserEnabled
    required property bool nodeEnabled
    required property bool profileSectionHasNotification
    required property bool showCreateCommunityBadge
    required property bool thirdpartyServicesEnabled

    required property bool acVisible
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
    modal: !alwaysVisible

    topPadding: Qt.platform.os === SQUtils.Utils.mac && Window.visibility !== Window.FullScreen ? Theme.padding * 3 // 48
                                                                                                : Theme.halfPadding // 8
    bottomPadding: Theme.halfPadding
    leftPadding: Theme.halfPadding
    rightPadding: Theme.halfPadding

    spacing: Theme.halfPadding // 8

    background: Rectangle {
        color: "transparent"
    }

    implicitWidth: 76 // by design; FIXME use a scalable value (60 + Theme.halfPadding + Theme.halfPadding)

    QtObject {
        id: d

        // UI
        readonly property int windowWidth: root.parent?.Window?.width ?? Screen.width
        readonly property int windowHeight: root.parent?.Window?.height ?? Screen.height

        readonly property color containerBgColor: {
            !root.thirdpartyServicesEnabled ? root.Theme.palette.privacyColors.primary :
                                              root.Theme.palette.isDark ? root.StatusColors.darkDesktopBlue10
                                                                        : root.StatusColors.lightDesktopBlue10 // FIXME correct container bg color
        }
        readonly property int containerBgRadius: root.Theme.padding // 16

        // models
        readonly property var sectionsModelInternal: SortFilterProxyModel {
            sourceModel: root.sectionsModel
            filters: [
                ValueFilter {
                    roleName: "sectionType"
                    value: Constants.appSection.loadingSection
                    inverted: true
                },
                ValueFilter {
                    roleName: "enabled"
                    value: true
                    enabled: root.showEnabledSectionsOnly
                }
            ]
            sorters: [
                RoleSorter { roleName: "sectionType" }
            ]
        }

        readonly property var regularItemsModel: SortFilterProxyModel {
            sourceModel: d.sectionsModelInternal
            filters: AnyOf {
                ValueFilter {
                    roleName: "sectionType"
                    value: Constants.appSection.homePage
                }
                ValueFilter {
                    roleName: "sectionType"
                    value: Constants.appSection.wallet
                }
                ValueFilter {
                    roleName: "sectionType"
                    value: Constants.appSection.swap
                    enabled: !root.marketEnabled
                }
                ValueFilter {
                    roleName: "sectionType"
                    value: Constants.appSection.market
                    enabled: root.marketEnabled
                }
                ValueFilter {
                    roleName: "sectionType"
                    value: Constants.appSection.chat
                }
                ValueFilter {
                    roleName: "sectionType"
                    value: Constants.appSection.browser
                    enabled: root.browserEnabled
                }
                ValueFilter {
                    roleName: "sectionType"
                    value: Constants.appSection.node
                    enabled: root.nodeEnabled
                }
            }
        }

        readonly property var communityItemsModel: SortFilterProxyModel {
            sourceModel: d.sectionsModelInternal
            filters: [
                ValueFilter {
                    roleName: "sectionType"
                    value: Constants.appSection.community
                }
            ]
        }

        readonly property var bottomItemsModel: SortFilterProxyModel {
            sourceModel: d.sectionsModelInternal
            filters: AnyOf {
                ValueFilter {
                    roleName: "sectionType"
                    value: Constants.appSection.communitiesPortal
                }
                ValueFilter {
                    roleName: "sectionType"
                    value: Constants.appSection.profile
                }
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: root.spacing

        // main section
        Control {
            Layout.fillWidth: true
            Layout.fillHeight: true
            topPadding: Theme.smallPadding // 10
            bottomPadding: Theme.smallPadding // 10

            background: Rectangle {
                color: d.containerBgColor
                radius: d.containerBgRadius
            }

            contentItem: ColumnLayout {
                // regular sections
                SidebarListView {
                    Layout.fillHeight: true
                    Layout.maximumHeight: contentHeight
                    model: d.regularItemsModel
                    delegate: RegularSectionButton {}
                }

                // communities
                SidebarListView {
                    Layout.fillHeight: true
                    model: d.communityItemsModel
                    delegate: CommunitySectionButton {
                        objectName: "CommunityNavBarButton"
                    }
                }

                // separator
                Rectangle {
                    Layout.preferredWidth: Theme.padding
                    Layout.preferredHeight: 1
                    Layout.alignment: Qt.AlignHCenter
                    color: Theme.palette.baseColor1
                }

                // settings + community portal
                SidebarListView {
                    Layout.preferredHeight: contentHeight
                    model: d.bottomItemsModel
                    delegate: BottomSectionButton {}
                }

                // own profile
                ProfileButton {
                    objectName: "statusProfileNavBarTabButton"
                    Layout.alignment: Qt.AlignHCenter
                    name: root.profileStore.name
                    pubKey: root.profileStore.pubKey
                    compressedPubKey: root.profileStore.compressedPubKey
                    iconSource: root.profileStore.icon
                    colorId: root.profileStore.colorId
                    currentUserStatus: root.profileStore.currentUserStatus
                    usesDefaultName: root.profileStore.usesDefaultName

                    getEmojiHashFn: root.getEmojiHashFn
                    getLinkToProfileFn: root.getLinkToProfileFn

                    onSetCurrentUserStatusRequested: (status) => root.setCurrentUserStatusRequested(status)
                    onViewProfileRequested: (pubKey) => root.viewProfileRequested(pubKey)
                }
            }
        }

        // AC button
        PrimaryNavSidebarButton {
            Layout.fillWidth: true
            Layout.preferredHeight: width

            id: acButton
            objectName: "Activity Center-navbar"

            checkable: true
            checked: root.acVisible

            sectionType: Constants.appSection.activityCenter
            icon.name: "notification"

            hasNotification: root.acHasUnseenNotifications
            notificationsCount: root.acUnreadNotificationsCount

            background: Rectangle {
                // prevent opacity multiplying; root has a "transparent" background!
                color: d.containerBgColor
                radius: d.containerBgRadius
                Rectangle {
                    anchors.fill: parent
                    color: {
                        if (acButton.checked)
                            return Theme.palette.primaryColor1
                        if (acButton.hovered)
                            return Theme.palette.primaryColor2
                        return "transparent"
                    }
                    Behavior on color { ColorAnimation { duration: ThemeUtils.AnimationDuration.Fast } }
                    radius: parent.radius
                }
            }

            onToggled: root.activityCenterRequested(checked)
        }
    }

    component RegularSectionButton: PrimaryNavSidebarButton {
        objectName: model.name + "-navbar"
        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined

        sectionId: model.id
        sectionType: model.sectionType
        checked: model.active
        icon.name: model.icon
        icon.source: model.image
        text: model.icon.length > 0 ? "" : model.name
        tooltipText: Utils.translatedSectionName(sectionType, model.name) // FIXME Utils.translatedSectionName to take model.name as fallback for community name

        hasNotification: model.hasNotification
        notificationsCount: model.notificationsCount

        onClicked: {
            root.itemActivated(model.sectionType, model.id)
            if (root.interactive)
                root.close()
        }
    }

    component CommunitySectionButton: RegularSectionButton {
        tooltipText: model.name
        popupMenu: root.communityPopupMenu

        StatusRoundIcon {
            visible: model.amIBanned
            width: Theme.padding
            height: width
            anchors.top: parent.top
            anchors.left: parent.right
            anchors.leftMargin: -width

            color: Theme.palette.dangerColor1
            border.color: d.containerBgColor
            border.width: 2
            asset.name: "cancel"
            asset.color: d.containerBgColor
            asset.width: Theme.smallPadding
        }

        Binding on icon.color {
            value: model.color
            when: !highlighted || !down || !checked
        }
    }

    component BottomSectionButton: RegularSectionButton {
        readonly property bool displayCreateCommunityBadge: model.sectionType === Constants.appSection.communitiesPortal && root.showCreateCommunityBadge
        showBadgeGradient: displayCreateCommunityBadge
        hasNotification: {
            if (model.sectionType === Constants.appSection.profile)
                return root.profileSectionHasNotification
            if (displayCreateCommunityBadge)
                return true
            return model.hasNotification
        }
    }

    component SidebarListView: ListView {
        Layout.fillWidth: true
        clip: true
        spacing: root.spacing
        interactive: contentHeight > height
    }
}
