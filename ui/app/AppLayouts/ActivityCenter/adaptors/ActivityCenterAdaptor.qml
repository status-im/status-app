import QtQuick

import StatusQ.Core.Theme
import StatusQ

import QtModelsToolkit
import SortFilterProxyModel

import AppLayouts.ActivityCenter.helpers

import utils

/*!
    \qmltype NotificationsAdaptor
    \inqmlmodule AppLayouts.ActivityCenter.adaptor

    Adaptor that transforms the backend notifications model into
    a UI-ready model consumed by NotificationCard and Activity Center views.

    Responsibilities:
    - Normalize backend notification data into a flat, UI-oriented role set
    - Derive presentation-specific roles (title, content, icons, attachments)
    - Hide backend complexity (nested objects, enums, raw flags)
    - Keep UI delegates simple and declarative

    This adaptor intentionally contains presentation logic.
    Visual components must not re-derive or reinterpret these values.
*/
QtObject {
    id: root

    /*!
        Backend-provided notifications model.

        Expected to be a QAbstractItemModel (or ListModel) whose roles
        match the Activity Center notification payload coming from core.

        This adapter assumes:
        - One row per notification
        - Stable role names (see expectedRoles below)

        Model structure (input):

        chatId               [string]  - unique identifier of the chat related to the notification, if applicable
        communityId          [string]  - unique identifier of the community, if applicable
        membershipStatus     [int]     - membership state of the user in the community
                                         (enum: ActivityCenterTypes.ActivityCenterMembershipStatus)
        sectionId            [string]  - section identifier used for navigation
                                         (e.g. chat, community, wallet)
        ***name                 [string]  - primary display name associated with the notification
                                         NOTE: TO REVIEW – seems to be only the channel name for a specific
                                         notification type (group chat invitation)

        newsTitle            [string]  - title of the news item, if the notification represents a news entry
        newsDescription      [string]  - short description or summary of the news
        newsContent          [string]  - full news content or body text
        newsImageUrl         [string]  - URL of the image associated with the news item
        newsLink             [string]  - external or internal link related to the news
        newsLinkLabel        [string]  - label displayed for the news link CTA

        notificationType     [int]     - type of notification
                                         (enum: ActivityCenterTypes.NotificationType)

        message              [object]  - message payload associated with the notification:
                                         {
                                           id                     [string]  - unique identifier of the message
                                           responseTo             [string]  - identifier of the original message
                                                                                this message is replying to
                                           communityId            [string]  - identifier of the community, if applicable
                                           messageText            [string]  - textual content of the message
                                           contentType            [int]     - message content type
                                                                                (enum: StatusMessage.ContentType)
                                           amISender              [bool]    - whether the current user is the sender
                                           contactRequestState    [int]     - contact request state
                                                                                (enum: ActivityCenterTypes.ActivityCenterContactRequestState)
                                           albumMessageImages     [string]  - space-separated list of album image URLs
                                           albumImagesCount       [int]     - number of images in the album
                                           messageImage           [string]  - image URL for image-based messages
                                           unparsedText           [string]  - raw/unparsed message text (if applicable)
                                         }

        timestamp            [double]  - timestamp of when the notification was created

        ***previousTimestamp    [double]  - timestamp of the previous related notification
                                         NOTE: TO REVIEW – deprecated?

        read                 [bool]    - whether the notification has been marked as read
        dismissed            [bool]    - whether the notification has been dismissed by the user
        accepted             [bool]    - whether the notification action (e.g. request) was accepted

        author               [string]  - author information associated with the notification

        repliedMessage       [object]  - reference to the replied message, if applicable:
                                         {
                                           contentType [int]    - type of the replied message content
                                                                 (enum: Constants.messageContentType)
                                           messageText [string] - text content of the replied message
                                         }

        chatType             [int]     - type of chat
                                         (enum: Constants.chatType)

        tokenData            [object]  - token-related metadata for community token notifications:
                                         {
                                           chainId        [string]  - blockchain network identifier
                                           txHash         [string]  - transaction hash
                                           walletAddress  [string]  - wallet address involved in the transaction
                                           isFirst        [bool]    - whether this is the first transaction of its kind
                                                                   (first community token received)
                                           communityId    [string]  - community identifier associated with the token, if any
                                           amount         [string]  - transferred token amount (raw or formatted)
                                           name           [string]  - token name
                                           symbol         [string]  - token symbol
                                           imageUrl       [string]  - URL of the token image
                                           tokenType      [int]     - token type
                                                                   (enum: Constants.TokenType)
                                         }

        ***installationId       [string]  - identifier of the installation/device that originated the event
                                         NOTE: TO REVIEW – not used in the current app
    */
    required property var notifications

    /*!
        Public model exposed to the UI.

        This model sits on top of ObjectProxyModel and represents the
        final, UI-ready notifications model consumed by Activity Center
        views and NotificationCard delegates.

        Responsibilities:
        - Filter dismissed notifications
        - Apply default ordering (newest first)

        This separation keeps ObjectProxyModel focused on data adaptation,
        while higher-level list concerns (filtering and sorting) remain optional
        and configurable.

        Model structure (output):

        id                   [string]  - notificaiton identifier
        notificationType     [int]     - notification type
        unread               [bool]    - whether the notification is unread
        selected             [bool]    - selection state (UI-managed)

        avatarSource         [string]  - avatar or preview image source
        badgeIconName        [string]  - badge icon name
        isCircularAvatar     [bool]    - whether the avatar is circular
        isAvatarClickable    [bool]    - whether the avatar is clickable or not
        avatarId             [string]  - avatar identifier (it can be a contact id or a
                                         community id depending on the notification context)
        avatarLetterColor     [color]  - background color for letter-based avatars
        avatarLetterText      [string] - source text used to derive avatar letters
        isAvatarLetterAcronym [bool]   - whether to generate an acronym from the source text
        avatarMaxTextLen      [int]    - maximum number of characters shown in the avatar

        title                [string]  - primary title text
        chatKey              [string]  - identifier used for navigation
        isContact            [bool]    - whether the notification refers to a contact
        trustIndicator       [int]     - trust / safety indicator
        isBlocked            [bool]    - whether the notification refers to a blocked contact

        primaryText          [string]  - primary context label
        contextAvatar        [url]     - primary text related avatar
        iconName             [string]  - context icon name
        secondaryText        [string]  - secondary context label
        separatorIconName    [string]  - separator icon name

        actionText           [string]  - call-to-action label

        preImageSource       [string]  - preview image source shown above content
        preImageRadius       [int]     - corner radius for preview image
        content              [string]  - main notification content
        attachments          [var]     - list of attachment URLs

        timestamp            [double]  - notification creation timestamp

        ** Passthrough roles (navigation / actions):
        chatId               [string]  - related chat identifier
        communityId          [string]  - related community identifier
        sectionId            [string]  - section identifier used for navigation
        subsectionId         [string]  - section-specific child identifier. For message
                                         redirects this is the chat id.
        subsectionItemId     [string]  - section-specific item identifier. For message
                                         redirects this is the message id.
        redirectToDetails    [bool]    - whether clicking the notification opens a
                                         section-specific detail view
        redirectToSection    [bool]    - whether clicking the notification opens a section
        redirectToCommunitySettingsSubsection [bool]
                                       - whether clicking the notification opens a community
                                         settings subsection
        communitySettingsSubsection     [int]
                                       - target community settings section
                                         (enum: Constants.CommunitySettingsSections)
        communitySettingsSubsectionItem [int]
                                       - target community settings subsection item
                                         (enum: Constants.CommunityMembershipSubSections)
        redirectToLink       [bool]    - whether clicking the notification opens a popup/link
        redirectToWallet     [bool]    - whether clicking the notification opens wallet activity
    */
    readonly property var model: SortFilterProxyModel {
        // Sort by newest first (dismissed entries already excluded upstream)
        sourceModel: d.objectProxy

        sorters: RoleSorter {
            roleName: "timestamp"
            ascendingOrder: false
        }
    }


    /*!
        Model containing all known contacts.

        This model is used by the notification adaptors to resolve
        contact-specific information (e.g. display name, avatar,
        trust status) for notifications that reference a user.

        Expected to be a QAbstractItemModel (or compatible) indexed
        by public key.
    */
    required property var contactsModel

    /*!
        Name of the current user profile.
    */
    required property string userProfileName

    // This object holds implementation details and helper properties
    // used internally by the adapter. It is not part of the public API
    // and must not be accessed by consumers.
    readonly property QtObject d: QtObject {

        // Pre-filter dismissed notifications before ObjectProxyModel to skip
        // heavy delegate processing for entries that will never be shown.
        // Community membership decisions are kept so pending/final states remain visible.
        readonly property SortFilterProxyModel filteredNotifications: SortFilterProxyModel {
            sourceModel: root.notifications
            filters: AnyOf {
                ValueFilter {
                    roleName: "dismissed"
                    value: false
                }
                AllOf {
                    ValueFilter {
                        roleName: "notificationType"
                        value: ActivityCenterTypes.NotificationType.CommunityMembershipRequest
                    }
                    ValueFilter {
                        roleName: "membershipStatus"
                        value: ActivityCenterTypes.ActivityCenterMembershipStatus.None
                        inverted: true
                    }
                }
            }
        }

        // Internal proxy responsible for transforming backend notification
        // rows into UI-ready roles.
        readonly property ObjectProxyModel objectProxy: ObjectProxyModel {
            sourceModel: d.filteredNotifications

            expectedRoles: [
                // Notification status / management
                "id", "notificationType", "timestamp", "read", "dismissed", "accepted",

                // Notification context
                "chatId", "communityId", "sectionId",

                // Messenger related information
                "message", "author", "repliedMessage", "chatType", "name",

                // Community related information
                "membershipStatus", "tokenData",

                // News related information
                "newsTitle", "newsDescription", "newsContent", "newsImageUrl", "newsLink", "newsLinkLabel"
            ]

            exposedRoles: [
                // Card states related
                "notificationId", "notificationType", "unread",

                // Avatar related
                "avatarSource", "badgeIconName", "isCircularAvatar", "isAvatarClickable", "avatarId",
                "avatarLetterColor", "avatarLetterText", "isAvatarLetterAcronym", "avatarMaxTextLen",

                // Header row related
                "title", "chatKey", "isContact", "trustIndicator", "isBlocked",

                // Context row related
                "primaryText", "contextAvatar", "iconName", "secondaryText", "separatorIconName",

                // Action text
                "actionText",

                // Content block related
                "preImageSource", "preImageRadius", "content", "attachments", "showQuickActions", "actionId",

                // Timestamp related
                "timestamp",

                // Passthrough for navigation/actions
                "sectionId", "subsectionId", "subsectionItemId", "redirectToDetails", "redirectToSection",
                "redirectToCommunitySettingsSubsection", "communitySettingsSubsection", "communitySettingsSubsectionItem",
                "redirectToLink", "redirectToWallet",

                // Used by the filter above
                "dismissed"
            ]

            delegate: QtObject {
                id: row

                // Normalized notification object (single shape)
                readonly property ActivityNotification notification: ActivityNotification {
                    notificationId: model.id ?? ""
                    chatId: model.chatId ?? ""
                    communityId: model.communityId ?? ""
                    membershipStatus: model.membershipStatus ?? 0
                    sectionId: model.sectionId ?? ""
                    name: model.name ?? ""
                    newsTitle: model.newsTitle ?? ""
                    newsDescription: model.newsDescription ?? ""
                    newsContent: model.newsContent ?? ""
                    newsImageUrl: model.newsImageUrl ?? ""
                    newsLink: model.newsLink ?? ""
                    newsLinkLabel: model.newsLinkLabel ?? ""
                    author: model.author ?? ""
                    notificationType: model.notificationType ?? 0
                    message: model.message ?? null
                    timestamp: model.timestamp ?? 0
                    previousTimestamp: model.previousTimestamp ?? 0
                    read: model.read ?? false
                    dismissed: model.dismissed ?? false
                    accepted: model.accepted ?? false
                    repliedMessage: model.repliedMessage ?? null
                    chatType: model.chatType ?? 0
                    tokenData: model.tokenData ?? null
                    installationId: model.installationId ?? ""
                }

                // Choose adaptor component (single branching point)
                readonly property Component adaptorComponent: {
                    switch (notification.notificationType ?? 0) {

                        // -------------------------
                        // Messenger Notifications
                        // -------------------------
                    case ActivityCenterTypes.NotificationType.Mention:
                        return mentionAdaptor
                    case ActivityCenterTypes.NotificationType.Reply:
                        return replyAdaptor
                    case ActivityCenterTypes.NotificationType.ContactRequest:
                        return contactRequestAdaptor
                    case ActivityCenterTypes.NotificationType.ContactRemoved:
                        return contactRemovedAdaptor
                    case ActivityCenterTypes.NotificationType.NewPrivateGroupChat:
                        return newPrivateGroupChatAdaptor

                        // -------------------------
                        // Community Notifications
                        // -------------------------
                    case ActivityCenterTypes.NotificationType.CommunityInvitation:
                        return communityInvitationAdaptor
                    case ActivityCenterTypes.NotificationType.CommunityMembershipRequest:
                        return communityMembershipRequestAdaptor
                    case ActivityCenterTypes.NotificationType.CommunityRequest:
                        return communityRequestAdaptor
                    case ActivityCenterTypes.NotificationType.CommunityKicked:
                        return communityKickedAdaptor
                    case ActivityCenterTypes.NotificationType.CommunityBanned:
                        return communityBannedAdaptor
                    case ActivityCenterTypes.NotificationType.CommunityUnbanned:
                        return communityUnbannedAdaptor
                    case ActivityCenterTypes.NotificationType.CommunityTokenReceived:
                        return communityTokenReceivedAdaptor
                    case ActivityCenterTypes.NotificationType.FirstCommunityTokenReceived:
                        return firstCommunityTokenReceivedAdaptor
                    case ActivityCenterTypes.NotificationType.OwnerTokenReceived:
                        return ownerTokenReceivedAdaptor
                    case ActivityCenterTypes.NotificationType.OwnershipReceived:
                        return ownershipReceivedAdaptor
                    case ActivityCenterTypes.NotificationType.OwnershipLost:
                        return ownershipLostAdaptor
                    case ActivityCenterTypes.NotificationType.OwnershipFailed:
                        return ownershipFailedAdaptor
                    case ActivityCenterTypes.NotificationType.OwnershipDeclined:
                        return ownershipDeclinedAdaptor
                    case ActivityCenterTypes.NotificationType.ShareAccounts:
                        return shareAccountsAdaptor

                        // -------------------------
                        // System Notifications
                        // -------------------------
                    case ActivityCenterTypes.NotificationType.NewInstallationReceived:
                        return newInstallationReceivedAdaptor
                    case ActivityCenterTypes.NotificationType.NewInstallationCreated:
                        return newInstallationCreatedAdaptor
                    case ActivityCenterTypes.NotificationType.ActivityCenterNotificationTypeNews:
                        return systemNewsAdaptor

                    default:
                        return baseAdaptor
                    }
                }

                // Keep a stable reference to the instantiated adaptor for this row
                property QtObject adaptor: null

                // Instantiate exactly one adaptor object per row
                readonly property Instantiator adaptorInst: Instantiator {
                    id: adaptorInst
                    model: 1
                    delegate: row.adaptorComponent

                    onObjectAdded: function(index, object) {
                        // Bind the newly created adaptor instance to this row
                        row.adaptor = object
                    }

                    onObjectRemoved: function(index, object) {
                        // Clear the reference when the adaptor is destroyed
                        if (row.adaptor === object)
                            row.adaptor = null
                    }
                }

                // Exposed roles (delegated to adaptor, with safe fallbacks)
                // -------------------------
                // Card state
                // -------------------------
                readonly property string notificationId: notification.notificationId
                readonly property int notificationType: notification.notificationType
                readonly property bool unread: !(notification.read ?? false)

                // -------------------------
                // Avatar / badge
                // -------------------------
                readonly property string avatarSource: adaptor?.avatarSource ?? ""
                readonly property string badgeIconName: adaptor?.badgeIconName ?? ""
                readonly property bool isCircularAvatar: adaptor?.isCircularAvatar ?? true
                readonly property bool isAvatarClickable: adaptor?.isAvatarClickable ?? false
                readonly property string avatarId: adaptor?.avatarId ?? ""
                readonly property color avatarLetterColor: adaptor?.avatarLetterColor ?? Theme.palette.miscColor5
                readonly property string avatarLetterText: adaptor?.avatarLetterText ?? ""
                readonly property bool isAvatarLetterAcronym: adaptor?.isAvatarLetterAcronym ?? true
                readonly property int avatarMaxTextLen: adaptor?.avatarMaxTextLen ?? 2

                // -------------------------
                // Header row
                // -------------------------
                readonly property string title: adaptor?.title ?? ""
                readonly property string chatKey: adaptor?.chatKey ?? ""
                readonly property bool isContact: adaptor?.isContact ?? false
                readonly property int trustIndicator: adaptor?.trustIndicator ?? 0
                readonly property int isBlocked: adaptor?.isBlocked ?? 0

                // -------------------------
                // Context row
                // -------------------------
                readonly property string primaryText: adaptor?.primaryText ?? ""
                readonly property url contextAvatar: adaptor?.contextAvatar ?? ""
                readonly property string iconName: adaptor?.iconName ?? ""
                readonly property string secondaryText: adaptor?.secondaryText ?? ""
                readonly property string separatorIconName: adaptor?.separatorIconName ?? "arrow-next"

                // -------------------------
                // Action text
                // -------------------------
                readonly property string actionText: adaptor?.actionText ?? ""

                // -------------------------
                // Content block
                // -------------------------
                readonly property string preImageSource: adaptor?.preImageSource ?? ""
                readonly property int preImageRadius: adaptor?.preImageRadius ?? Theme.radius
                readonly property string content: adaptor?.content ?? ""
                readonly property var attachments: adaptor?.attachments ?? []
                readonly property bool showQuickActions: adaptor?.showQuickActions ?? false
                readonly property string actionId: adaptor?.actionId ?? ""

                readonly property double timestamp: notification.timestamp

                // ---------------------------------
                // Passthrough / navigation related
                // ---------------------------------
                readonly property string sectionId: model.sectionId || model.communityId
                readonly property string subsectionId: model.chatId
                readonly property string subsectionItemId: adaptor?.subsectionItemId ?? ""
                readonly property bool dismissed: model.dismissed
                readonly property bool redirectToDetails: adaptor?.redirectToDetails ?? false
                readonly property bool redirectToSection: adaptor?.redirectToSection ?? false
                readonly property bool redirectToCommunitySettingsSubsection: adaptor?.redirectToCommunitySettingsSubsection ?? false
                readonly property int communitySettingsSubsection: adaptor?.communitySettingsSubsection ?? -1
                readonly property int communitySettingsSubsectionItem: adaptor?.communitySettingsSubsectionItem ?? -1
                readonly property bool redirectToLink: adaptor?.redirectToLink ?? false
                readonly property bool redirectToWallet: adaptor?.redirectToWallet ?? false

                // All specific adaptor components definition
                readonly property Component baseAdaptor: Component {

                    NotificationAdaptorBase {
                        notification: row.notification
                    }
                }

                readonly property Component mentionAdaptor: Component {

                    NotificationAdaptorMessenger {

                        // Required data
                        readonly property var community: (context.isCommunity && notification.message) ?
                                                             root.getCommunityDetails(notification.message.communityId) : null
                        readonly property var chat: ((context.isCommunity || context.isGroup) &&
                                                     notification.chatId && notification.chatId.length > 0)
                                                    ? root.getChatDetails(notification.chatId) : null


                        notification: row.notification
                        contactsModel: root.contactsModel

                        // Avatar related
                        badgeIconName: "action-mention"

                        // Context related
                        context.contextAvatar: context.isCommunity ? community?.image ?? ""
                                                                   : context.isGroup ? chat?.icon ?? "" : ""
                        context.contextPrimaryName: context.isCommunity ? community?.name ?? ""
                                                                        : context.isGroup ? chat?.name ?? "" : ""
                        context.contextSecondaryName: context.isCommunity ? chat?.name ?? "" : ""

                        onPopulateContactDetailsRequested: (contactId) => root.populateContactDetailsRequested(contactId)
                    }
                }

                readonly property Component replyAdaptor: Component {

                    NotificationAdaptorMessenger {

                        // Required data
                        readonly property var community: (context.isCommunity && notification.message) ?
                                                             root.getCommunityDetails(notification.message.communityId) : null
                        readonly property var chat: ((context.isCommunity || context.isGroup) &&
                                                     notification.chatId && notification.chatId.length > 0)
                                                    ? root.getChatDetails(notification.chatId) : null


                        notification: row.notification
                        contactsModel: root.contactsModel

                        // Avatar related
                        badgeIconName: "action-reply"

                        // Context related
                        context.contextAvatar: context.isCommunity ? community?.image ?? ""
                                                                   : context.isGroup ? chat?.icon ?? "" : ""
                        context.contextPrimaryName: context.isCommunity ? community?.name ?? ""
                                                                        : context.isGroup ? chat?.name ?? "" : ""
                        context.contextSecondaryName: context.isCommunity ? chat?.name ?? "" : ""

                        onPopulateContactDetailsRequested: (contactId) => root.populateContactDetailsRequested(contactId)
                    }
                }

                readonly property Component contactRequestAdaptor: Component {

                    NotificationAdaptorContactRequest {

                        // Required data
                        notification: row.notification
                        contactsModel: root.contactsModel

                        onPopulateContactDetailsRequested: (contactId) => root.populateContactDetailsRequested(contactId)
                    }
                }

                readonly property Component contactRemovedAdaptor: Component {

                    NotificationAdaptorSender {
                        // Required data
                        notification: row.notification
                        contactsModel: root.contactsModel

                        // Avatar related
                        badgeIconName: "action-warn"

                        // Header row related
                        title: sender.displayName
                        chatKey: sender.compressedPubKey
                        isContact: sender.isContact
                        trustIndicator: sender.trustIndicator
                        isBlocked: sender.isBlocked

                        // Action text
                        actionText: qsTr("Removed you from contacts")

                        onPopulateContactDetailsRequested: (contactId) => root.populateContactDetailsRequested(contactId)
                    }
                }

                readonly property Component newPrivateGroupChatAdaptor: Component {

                    NotificationAdaptorBase {

                        // Required data
                        readonly property var chat: (notification.chatId && notification.chatId.length > 0)
                                                    ? root.getChatDetails(notification.chatId)
                                                    : null

                        notification: row.notification

                        // Avatar related
                        badgeIconName: "action-add"
                        avatarSource: chat?.icon ?? ""
                        avatarLetterColor: chat?.color ?? ""
                        avatarLetterText: title
                        isCircularAvatar: true

                        // Header row related
                        title: notification.name

                        // Action text
                        actionText: qsTr("You’re added to private group chat")

                        content: {
                            if(notification.accepted)
                                return "<font color='%1'>".arg(Theme.palette.successColor1) + qsTr("Accepted") + "</font>"

                            if(notification.dismissed)
                                return "<font color='%1'>".arg(Theme.palette.dangerColor1) + qsTr("Decline") + "</font>"

                            return ""
                        }

                        // Navigation related
                        subsectionItemId: notification && notification.message ? notification.message.id : ""
                        redirectToDetails: notification.accepted || notification.dismissed // If pending

                        // Quick actions related
                        showQuickActions: !notification.accepted && !notification.dismissed
                        actionId: notification.notificationId
                    }
                }

                readonly property Component communityInvitationAdaptor: Component {

                    NotificationAdaptorCommunity {

                        // Required data
                        readonly property NotificationSenderResolver senderResolver: NotificationSenderResolver {
                            isOutgoingMessage: row.notification?.message?.amISender ?? false
                            contactId: row.notification ? (isOutgoingMessage ? row.notification.chatId : row.notification.author) : ""
                            contactsModel: root.contactsModel

                            onPopulateContactDetailsRequested: (contactId) => root.populateContactDetailsRequested(contactId)
                        }
                        notification: row.notification
                        getCommunityDetails: root.getCommunityDetails

                        // Avatar related
                        badgeIconName: "action-add"

                        // Header related
                        title: senderResolver.sender?.displayName ?? ""
                        chatKey: senderResolver.sender?.compressedPubKey ?? ""
                        isContact: senderResolver.sender?.isContact ?? false
                        trustIndicator: senderResolver?.trustIndicator ?? Constants.trustStatus.unknown
                        isBlocked: senderResolver?.isBlocked ?? false

                        // Action text
                        actionText: qsTr("Invitation to join community")
                    }
                }

                readonly property Component communityMembershipRequestAdaptor: Component {

                    NotificationAdaptorCommunity {

                        // Required data
                        readonly property int membershipStatus: notification && notification.membershipStatus ?
                                                                    notification.membershipStatus :
                                                                    ActivityCenterTypes.ActivityCenterMembershipStatus.None
                        readonly property bool pending: membershipStatus === ActivityCenterTypes.ActivityCenterMembershipStatus.Pending
                        readonly property bool accepted: membershipStatus === ActivityCenterTypes.ActivityCenterMembershipStatus.Accepted
                        readonly property bool declined: membershipStatus === ActivityCenterTypes.ActivityCenterMembershipStatus.Declined
                        readonly property bool acceptedPending: membershipStatus === ActivityCenterTypes.ActivityCenterMembershipStatus.AcceptedPending
                        readonly property bool declinedPending: membershipStatus === ActivityCenterTypes.ActivityCenterMembershipStatus.DeclinedPending

                        readonly property NotificationSenderResolver senderResolver: NotificationSenderResolver {
                            isOutgoingMessage: row.notification?.message?.amISender ?? false
                            contactId: row.notification ? (isOutgoingMessage ? row.notification.chatId : row.notification.author) : ""
                            contactsModel: root.contactsModel

                            onPopulateContactDetailsRequested: (contactId) => root.populateContactDetailsRequested(contactId)
                        }
                        notification: row.notification
                        getCommunityDetails: root.getCommunityDetails

                        // Avatar related
                        badgeIconName: "action-admin"

                        // Action text
                        actionText: qsTr("Community membership request")

                        // Navigation related
                        redirectToSection: false
                        redirectToCommunitySettingsSubsection: true
                        communitySettingsSubsection: Constants.CommunitySettingsSections.Members
                        communitySettingsSubsectionItem: Constants.CommunityMembershipSubSections.MembershipRequests

                        // Content related
                        content: {
                            const sender = senderResolver.sender?.displayName
                                           ? "<font color='%1'>@%2</font>".arg(Theme.palette.primaryColor1)
                                                                          .arg(senderResolver.sender.displayName)
                                           : ""
                            const status = accepted ? "<font color='%1'>%2</font>".arg(Theme.palette.successColor1).arg(qsTr("Accepted"))
                                                    : declined ? "<font color='%1'>%2</font>".arg(Theme.palette.dangerColor1).arg(qsTr("Declined"))
                                                               : acceptedPending ? qsTr("Accept pending")
                                                                                 : declinedPending ? qsTr("Reject pending")
                                                                                                   : qsTr("Pending")
                            return pending && sender ? sender :
                                                       sender ? sender + "<br>" + status : status
                        }

                        // Quick actions — only when genuinely pending (excludes AcceptedPending=4, DeclinedPending=5)
                        showQuickActions: pending
                        actionId: pending ? notification.notificationId : ""
                    }
                }

                readonly property Component communityRequestAdaptor: Component {

                    NotificationAdaptorCommunity {

                        readonly property int membershipStatus: notification && notification.membershipStatus ?
                                                                    notification.membershipStatus :
                                                                    ActivityCenterTypes.ActivityCenterMembershipStatus.None
                        readonly property bool accepted: membershipStatus === ActivityCenterTypes.ActivityCenterMembershipStatus.Accepted
                        readonly property bool declined: membershipStatus === ActivityCenterTypes.ActivityCenterMembershipStatus.Declined
                        readonly property bool pending: !accepted && !declined

                        // Required data
                        notification: row.notification
                        getCommunityDetails: root.getCommunityDetails

                        // Avatar related
                        badgeIconName: "action-green-airplane"

                        // Action text
                        actionText: qsTr("Request to join community")

                        // Content options
                        content: {
                            if(accepted)
                                return "<font color='%1'>".arg(Theme.palette.successColor1) + qsTr("Accepted") + "</font>"

                            if(declined)
                                return "<font color='%1'>".arg(Theme.palette.dangerColor1) + qsTr("Declined") + "</font>"

                            if(pending)
                                return qsTr("In progress")
                        }
                    }
                }

                readonly property Component communityKickedAdaptor: Component {

                    NotificationAdaptorCommunity {

                        // Required data
                        notification: row.notification
                        getCommunityDetails: root.getCommunityDetails

                        // Avatar related
                        badgeIconName: "action-warn"

                        // Content related
                        content: qsTr("You have been kicked out of community")
                    }
                }

                readonly property Component communityBannedAdaptor: Component {

                    NotificationAdaptorCommunity {

                        // Required data
                        notification: row.notification
                        getCommunityDetails: root.getCommunityDetails

                        // Avatar related
                        badgeIconName: "action-warn"

                        // Content related
                        content: qsTr("You have been <font color='%1'>banned</font> from community").arg(String(Theme.palette.dangerColor1))
                    }
                }

                readonly property Component communityUnbannedAdaptor: Component {

                    NotificationAdaptorCommunity {

                        // Required data
                        notification: row.notification
                        getCommunityDetails: root.getCommunityDetails

                        // Avatar related
                        badgeIconName: "action-check"

                        // Content related
                        content: qsTr("You have been <font color='%1'>unbanned</font> in community").arg(String(Theme.palette.successColor1))
                    }
                }

                readonly property Component communityTokenReceivedAdaptor: Component {

                    NotificationAdaptorCommunityToken {

                        // Required data
                        notification: row.notification
                        getCommunityDetails: root.getCommunityDetails

                        // Avatar related
                        badgeIconName: "action-coin"

                        // Content related
                        content: qsTr("You’re received a token in community")
                    }
                }

                readonly property Component firstCommunityTokenReceivedAdaptor: Component {

                    NotificationAdaptorCommunityToken {

                        // Required data
                        notification: row.notification
                        getCommunityDetails: root.getCommunityDetails

                        // Avatar related
                        badgeIconName: "action-coin"

                        // Action text
                        actionText: qsTr("You received your first community token")

                        // Content related
                        content: qsTr("<b>%1 %2 (%3) minted by %4.</b><br>").arg(tokenAmount).arg(tokenName).arg(tokenSymbol).arg(context.contextPrimaryName) +
                                 qsTr("Community tokens are created by the community and aren’t verified. Always check their source before interacting.")
                    }
                }

                readonly property Component ownerTokenReceivedAdaptor: Component {

                    NotificationAdaptorCommunityToken {

                        // Required data
                        notification: row.notification
                        getCommunityDetails: root.getCommunityDetails

                        // Avatar related
                        badgeIconName: "action-admin"

                        // Content related
                        content: qsTr("You received the owner token")
                    }
                }

                readonly property Component ownershipReceivedAdaptor: Component {

                    NotificationAdaptorCommunity {

                        // Required data
                        notification: row.notification
                        getCommunityDetails: root.getCommunityDetails

                        // Avatar related
                        badgeIconName: "action-admin"

                        // Action text
                        actionText: qsTr("Ownership transfer")

                        // Content related
                        content: "<font color='%1'>".arg(Theme.palette.successColor1) + qsTr("You are now the owner of the community") + "</font>"
                    }
                }

                readonly property Component ownershipLostAdaptor: Component {

                    NotificationAdaptorCommunity {

                        // Required data
                        notification: row.notification
                        getCommunityDetails: root.getCommunityDetails

                        // Avatar related
                        badgeIconName: "action-admin"

                        // Action text
                        actionText: qsTr("Ownership transfer")

                        // Content related
                        content: "<font color='%1'>".arg(Theme.palette.dangerColor1) + qsTr("You no longer control the community") + "</font>"
                    }
                }

                readonly property Component ownershipFailedAdaptor: Component {

                    NotificationAdaptorCommunity {

                        // Required data
                        notification: row.notification
                        getCommunityDetails: root.getCommunityDetails

                        // Avatar related
                        badgeIconName: "action-admin"

                        // Action text
                        actionText: qsTr("Ownership transfer")

                        // Content related
                        content: "<font color='%1'>".arg(Theme.palette.dangerColor1) + qsTr("Failed") + "</font>"
                    }
                }

                readonly property Component ownershipDeclinedAdaptor: Component {

                    NotificationAdaptorCommunity {

                        // Required data
                        notification: row.notification
                        getCommunityDetails: root.getCommunityDetails

                        // Avatar related
                        badgeIconName: "action-admin"

                        // Action text
                        actionText: qsTr("Ownership transfer")

                        // Content related
                        content: "<font color='%1'>".arg(Theme.palette.dangerColor1) + qsTr("Declined") + "</font>"
                    }
                }

                readonly property Component shareAccountsAdaptor: Component {

                    NotificationAdaptorCommunity {

                        // Required data
                        notification: row.notification
                        getCommunityDetails: root.getCommunityDetails

                        // Avatar related
                        badgeIconName: "action-warn"

                        // Content related
                        content: qsTr("To continue to be a member of community, you need to share your accounts")
                    }
                }

                readonly property Component newInstallationReceivedAdaptor: Component {

                    NotificationAdaptorBase {
                        notification: row.notification

                        avatarSource: Assets.png("status-logo-icon")
                        title: qsTr("Status")
                        actionText: qsTr("New device detected")
                        content: qsTr("New device with %1 profile has been detected.").arg(root.userProfileName)
                    }
                }

                readonly property Component newInstallationCreatedAdaptor: Component {

                    NotificationAdaptorBase {
                        notification: row.notification

                        avatarSource: Assets.png("status-logo-icon")
                        title: qsTr("Status")
                        actionText: qsTr("Sync your profile")
                        content: qsTr("Check your other device for a pairing request.")
                    }
                }

                readonly property Component systemNewsAdaptor: Component {

                    NotificationAdaptorSystemNews {
                        notification: row.notification
                    }
                }
            }
        }
    }

    /*!
        Resolves community details for a given community id.

        This function must be provided by the consumer of the adaptor.

        @param communityId [string]
        @return            [object|null] Community details (e.g. name, image)
    */
    property var getCommunityDetails: function(communityId) { return null }

    /*!
        Resolves chat or channel details for a given chat id.

        This function must be provided by the consumer of the adaptor.

        @param chatId  [string]
        @return        [object|null] Chat details (e.g. name, image)
    */
    property var getChatDetails: function(chatId) { return null }

    /*!
        Requests loading of additional data for the given contact.
    */
    signal populateContactDetailsRequested(string contactId)
}
