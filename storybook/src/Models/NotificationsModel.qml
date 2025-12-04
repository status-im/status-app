import QtQuick

import StatusQ.Core.Theme

// ***
// This model provides examples of all notification types supported by the Status app,
// showcasing the different visual states and UI variations for each notification card.
// ***
//
// Here is an example of the complete set of properties that a `Notification model` can contain:
//{
//    // Card states related
//    unread: false,
//    selected: false,
//
//    // Avatar related
//    avatarSource: "https://i.pravatar.cc/128?img=8",
//    badgeIconName: "action-mention",
//    isCircularAvatar: true,
//
//    // Header row related
//    title: "Notification 2",
//    chatKey: "zQ3saskd11lfkjs1dkf5Rj9",
//    isContact: true,
//    trustIndicator: 0,
//
//    // Context row related
//    primaryText: "Communities",
//    iconName: "communities",
//    secondaryText: "Channel 12",
//    separatorIconName: "arrow-next",
//
//    // Action text
//    actionText: "Action Text",
//
//    // Content block related
//    preImageSource: "https://picsum.photos/320/240?6",
//    preImageRadius: 8,
//    content: "Some notification description that can be long and long and long",
//    attachments: [
//                    "https://picsum.photos/320/240?1",
//                    "https://picsum.photos/320/240?2",
//                    "https://picsum.photos/320/240?9"
//                    ],
//
//    // Timestamp related
//    timestamp: 1765799225000
//}
//
ListModel {
    id: root

    readonly property var data: [
        {
            // MENTION IN 1:1 TYPE
            // Card states related
            unread: false,
            selected: false,

            // Avatar related
            avatarSource: "https://i.pravatar.cc/128?img=45",
            badgeIconName: "action-mention",
            isCircularAvatar: true,

            // Header row related
            title: "anna.eth",
            chatKey: "zQ3shuV7mZextijeBSDpgaq2EvebPGEeCrkH9AgmpCM7JTAAA",
            isContact: false,
            trustIndicator: 0,

            // Content block related
            content: "hey, <a href='robert.eth'>@robert.eth</a>, " +
                     "Do we still plan to ship this with v2.1 or postpone to the next release cycle?",

            // Timestamp related
            timestamp: 1765799225000
        },
        {
            // REPLY 1:1 TYPE
            // Card states related
            unread: true,
            selected: false,

            // Avatar related
            avatarSource: "https://i.pravatar.cc/128?img=5",
            badgeIconName: "action-reply",
            isCircularAvatar: true,

            // Header row related
            title: "anna.eth with long nickname",
            chatKey: "zQ3142hUdnpxi26rLmgdUwNxHgcbcYFW75JcSvVych58QVXXT",
            isContact: true,
            trustIndicator: 0,

            // Content block related
            content: "hey, Do we still plan to ship this with v2.1 or postpone to the next release cycle? we’re discussed it on the last meet",

            // Timestamp related
            timestamp: 1729799225000
        },
        {
            // CONTACT REQUEST TYPE
            // Card states related
            unread: true,
            selected: false,

            // Avatar related
            avatarSource: "https://i.pravatar.cc/128?img=15",
            badgeIconName: "action-add",
            isCircularAvatar: true,

            // Header row related
            title: "simon-dev.eth",
            chatKey: "z1425uV7mZextijeBSDpgaq2EvebPGEeCrkH9AgmpCM7JTp7A",
            isContact: false,
            trustIndicator: 0,

            // Action text
            actionText: "New contact request",

            // Content block related
            content: "Hey! I came across your profile and thought it’d be nice to connect. Always happy to meet new people here 🙂",

            // Timestamp related
            timestamp: 1765909333000
        },
        {
            // CONTACT REMOVED TYPE
            // Card states related
            unread: true,
            selected: false,

            // Avatar related
            avatarSource: "https://i.pravatar.cc/128?img=20",
            badgeIconName: "action-warn",
            isCircularAvatar: true,

            // Header row related
            title: "Sunshine",
            chatKey: "zQ3shgUZD14523iavJnT8rMhkzZ1RzLdioS2J6dZyVp3JosEQ",
            isContact: true,
            trustIndicator: 1,

            // Action text
            actionText: "Removed you from contacts",

            // Timestamp related
            timestamp: 1765329333000
        },
        {
            // NEW PRIVATE GROUP CHAT TYPE
            // Card states related
            unread: true,
            selected: false,

            // Avatar related
            avatarSource: "https://i.pravatar.cc/128?img=8",
            badgeIconName: "action-add",
            isCircularAvatar: true,

            // Header row related
            title: "rockstar.eth",
            chatKey: "z0000uV7mZextijeBSDpgaq2EvebPGEeCrkH9AgmpCM7JTAAA",
            isContact: true,
            trustIndicator: 2,

            // Context row related
            primaryText: "Summer Vacation",

            // Action text
            actionText: "You're added to private group chat",

            // Timestamp related
            timestamp: 1665909333000
        },
        {
            // MENTION IN GROUP CHAT TYPE
            // Card states related
            unread: false,
            selected: false,

            // Avatar related
            avatarSource: "https://i.pravatar.cc/128?img=1",
            badgeIconName: "action-mention",
            isCircularAvatar: true,

            // Header row related
            title: "anna.eth",
            chatKey: "zAMNAuV7mZextijeBSDpgaq2EvebPGEeCrkH9AgmpCM7JTXcA",
            isContact: true,
            trustIndicator: 1,

            // Context row related
            primaryText: "Summer Vacation",

            // Content block related
            content: "Hey <a href='rockstar.eth'>@rockstar.eth</a> 👋 just wanted to check something with you.",

            // Timestamp related
            timestamp: 1699009333000
        },
        {
            // REPLY IN GROUP CHAT TYPE
            // Card states related
            unread: true,
            selected: false,

            // Avatar related
            avatarSource: "https://i.pravatar.cc/128?img=21",
            badgeIconName: "action-reply",
            isCircularAvatar: true,

            // Header row related
            title: "Buddy",
            chatKey: "zAMZAuV7mZextijeBSDpgaq2EvebPGEeCrkH9AgmpCM7JTXcA",
            isContact: false,
            trustIndicator: 0,

            // Context row related
            primaryText: "UI Group Chat",

            // Content block related
            content: "Hi Pal! Saw your message and wanted to reply real quick.",

            // Timestamp related
            timestamp: 1755329333000
        },
        {
            // MENTION IN COMMUNITY TYPE
            // Card states related
            unread: true,
            selected: false,

            // Avatar related
            avatarSource: ModelsData.icons.cryptPunks,
            badgeIconName: "action-mention",
            isCircularAvatar: true,

            // Header row related
            title: "Mate-Mate",
            chatKey: "zAQshuV7mZextijeBSDpgaq2EvebPGEeCrkH9AgmpCM7JTA12",
            isContact: true,
            trustIndicator: 0,

            // Context row related
            primaryText: "CryptoPunks",
            iconName: "communities",
            secondaryText: "#design",
            separatorIconName: "arrow-next",

            // Content block related
            content: "<a href='pepe.eth'>@pepe.eth</a> I’ve just mentioned you in a conversation you might find interesting.",

            // Timestamp related
            timestamp: 1765799225000
        },
        {
            // REPLY IN COMMUNITY TYPE
            // Card states related
            unread: false,
            selected: false,

            // Avatar related
            avatarSource: ModelsData.icons.cryptPunks,
            badgeIconName: "action-reply",
            isCircularAvatar: true,

            // Header row related
            title: "Friend",
            chatKey: "zAssshuV7mZextijeBSDpgaq2EvebPGEeCrkH9AgmpCM7Jss12",
            isContact: true,
            trustIndicator: 1,

            // Context row related
            primaryText: "CryptoPunks",
            iconName: "communities",
            secondaryText: "#design",
            separatorIconName: "arrow-next",

            // Content block related
            content: "Do we still plan to ship this with v2.1, or should we postpone it to the next release cycle?
                      From my side, I think it would be good to clarify this soon so we can align expectations and avoid last-minute changes. Depending on the scope and remaining work, we can either lock it down for v2.1 or consciously move it to the next iteration and treat it as a follow-up improvement.",

            // Timestamp related
            timestamp: 1735799225000
        },
        {
            // INVITATION TO COMMUNITY TYPE
            // Card states related
            unread: true,
            selected: false,

            // Avatar related
            avatarSource: ModelsData.icons.socks,
            badgeIconName: "action-add",
            isCircularAvatar: true,

            // Header row related
            title: "anna.eth",
            chatKey: "z123shuV7mZextijeBSDpgaq2EvebPGEeCrkH9AgmpCM7Jsaaa",
            isContact: false,
            trustIndicator: 1,

            // Context row related
            primaryText: "Socks Super Long Long Community Name ",
            iconName: "communities",
            secondaryText: "#design",
            separatorIconName: "arrow-next",

            // Action text
            actionText: "Invitation to join community",

            // Timestamp related
            timestamp: 1745799225000
        },
        {
            // MEMBERSHIP REQUEST TO COMMUNITY TYPE
            // Card states related
            unread: true,
            selected: false,

            // Avatar related
            avatarSource: ModelsData.icons.socks,
            badgeIconName: "action-admin",
            isCircularAvatar: true,

            // Context row related
            primaryText: "Socks Super Long Long Community Name ",
            iconName: "communities",

            // Action text
            actionText: "<a href='pepe.eth'>@pepe.eth</a> requested membership in your community",

            // Timestamp related
            timestamp: 1755799225000
        },
        {
            // MEMBERSHIP REQUEST ACCEPTED TO COMMUNITY TYPE
            // Card states related
            unread: false,
            selected: false,

            // Avatar related
            avatarSource: ModelsData.icons.socks,
            badgeIconName: "action-check",
            isCircularAvatar: true,

            // Context row related
            primaryText: "Socks Community Name ",
            iconName: "communities",

            // Action text
            actionText: "Request to join community accepted",

            // Timestamp related
            timestamp: 1765799225000
        },
        {
            // KICKED FROM COMMUNITY TYPE
            // Card states related
            unread: false,
            selected: false,

            // Avatar related
            avatarSource: ModelsData.icons.socks,
            badgeIconName: "action-warn",
            isCircularAvatar: true,

            // Context row related
            primaryText: "Socks Super Long Long Community Name ",
            iconName: "communities",

            // Action text
            actionText: "You have been kicked out of community",

            // Timestamp related
            timestamp: 1766899225000
        },
        {
            // COMMUNITY TOKEN RECEIVED TYPE
            // Card states related
            unread: true,
            selected: false,

            // Avatar related
            avatarSource: ModelsData.icons.dribble,
            badgeIconName: "action-coin",
            isCircularAvatar: true,

            // Context row related
            primaryText: "Dribble",
            iconName: "communities",

            // Action text
            actionText: "You're received a token in community",

            // Timestamp related
            timestamp: 1765699225000
        },
        {
            // FIRST COMMUNITY TOKEN RECEIVED TYPE
            // Card states related
            unread: true,
            selected: false,

            // Avatar related
            avatarSource: ModelsData.icons.dribble,
            badgeIconName: "action-coin",
            isCircularAvatar: true,

            // Context row related
            primaryText: "Dribble",
            iconName: "communities",

            // Action text
            actionText: "You're received a first community token",

            // Timestamp related
            timestamp: 1765688225000
        },
        {
            // BANNED FROM COMMUNITY TYPE
            // Card states related
            unread: true,
            selected: false,

            // Avatar related
            avatarSource: ModelsData.icons.dribble,
            badgeIconName: "action-warn",
            isCircularAvatar: true,

            // Context row related
            primaryText: "Dribble",
            iconName: "communities",

            // Action text
            actionText: "You were banned from community",

            // Timestamp related
            timestamp: 1766988225000
        },
        {
            // UNBANNED FROM COMMUNITY TYPE
            // Card states related
            unread: true,
            selected: false,

            // Avatar related
            avatarSource: ModelsData.icons.dribble,
            badgeIconName: "action-check",
            isCircularAvatar: true,

            // Context row related
            primaryText: "Dribble",
            iconName: "communities",

            // Action text
            actionText: "You have been unbanned in community",

            // Timestamp related
            timestamp: 1760988225000
        },
        {
            // OWNER TOKEN RECEIVED TYPE
            // Card states related
            unread: true,
            selected: false,

            // Avatar related
            avatarSource: ModelsData.icons.spotify,
            badgeIconName: "action-admin",
            isCircularAvatar: true,

            // Context row related
            primaryText: "Music and Sound",
            iconName: "communities",

            // Action text
            actionText: "You received the owner token from <a href='robert.eth'>@robert.eth</a>",

            // Timestamp related
            timestamp: 1760999225000
        },
        {
            // OWNERSHIP RECEIVED TYPE
            // Card states related
            unread: true,
            selected: false,

            // Avatar related
            avatarSource: ModelsData.icons.spotify,
            badgeIconName: "action-admin",
            isCircularAvatar: true,

            // Context row related
            primaryText: "Music and Sound",
            iconName: "communities",

            // Action text
            actionText: "You are now the owner of the community",

            // Timestamp related
            timestamp: 1760859225000
        },
        {
            // OWNERSHIP LOST TYPE
            // Card states related
            unread: false,
            selected: false,

            // Avatar related
            avatarSource: ModelsData.icons.spotify,
            badgeIconName: "action-admin",
            isCircularAvatar: true,

            // Context row related
            primaryText: "Music and Sound",
            iconName: "communities",

            // Action text
            actionText: "You no longer control the community",

            // Timestamp related
            timestamp: 1770859225000
        },
        {
            // OWNERSHIP TRANSFER FAILED TYPE
            // Card states related
            unread: false,
            selected: false,

            // Avatar related
            avatarSource: ModelsData.icons.spotify,
            badgeIconName: "action-admin",
            isCircularAvatar: true,

            // Context row related
            primaryText: "Music and Sound",
            iconName: "communities",

            // Action text
            actionText: "Ownership transfer failed",

            // Timestamp related
            timestamp: 1767759225000
        },
        {
            // OWNERSHIP TRANSFER DECLINED TYPE
            // Card states related
            unread: true,
            selected: false,

            // Avatar related
            avatarSource: ModelsData.icons.spotify,
            badgeIconName: "action-admin",
            isCircularAvatar: true,

            // Context row related
            primaryText: "Music and Sound",
            iconName: "communities",

            // Action text
            actionText: "Ownership transfer declined",

            // Timestamp related
            timestamp: 1767785225000
        },
        {
            // SYSTEM - NEW INSTALLATION TYPE
            // Card states related
            unread: true,
            selected: false,

            // Avatar related
            avatarSource: Assets.png("status-logo-icon"),
            isCircularAvatar: false,


            // Header row related
            title: "Status",

            // Content block related
            content: "New installation received from iPhoneABC",

            // Timestamp related
            timestamp: 1759995225000
        },
        {
            // SYSTEM - FETCHING BACKUP TYPE
            // Card states related
            unread: false,
            selected: false,

            // Avatar related
            avatarSource: Assets.png("status-logo-icon"),
            badgeIconName: "action-sync",
            isCircularAvatar: false,


            // Header row related
            title: "Status",

            // Content block related
            content: "Backup syncing fetching",

            // Timestamp related
            timestamp: 1759895225000
        },
        {
            // SYSTEM - BACKUP SYNCING PARTIAL FAIL TYPE
            // Card states related
            unread: false,
            selected: false,

            // Avatar related
            avatarSource: Assets.png("status-logo-icon"),
            badgeIconName: "action-sync-fail",
            isCircularAvatar: false,


            // Header row related
            title: "Status",

            // Content block related
            content: "Backup sync partially failed",

            // Timestamp related
            timestamp: 1759795225000
        },
        {
            // SYSTEM - BACKUP SYNCING FAILURE TYPE
            // Card states related
            unread: false,
            selected: false,

            // Avatar related
            avatarSource: Assets.png("status-logo-icon"),
            badgeIconName: "action-sync-fail",
            isCircularAvatar: false,


            // Header row related
            title: "Status",

            // Content block related
            content: "Backup sync failed",

            // Timestamp related
            timestamp: 1759887225000
        },
        {
            // SYSTEM - NEWS ARTICLE TYPE
            // Card states related
            unread: true,
            selected: false,

            // Avatar related
            avatarSource: Assets.png("status-logo-icon"),
            isCircularAvatar: false,

            // Header row related
            title: "Status",

            // Content block related
            preImageSource: "https://picsum.photos/320/240?6",
            preImageRadius: 8,
            content: "Update on notifications section will be rolled out to all users next week. Be prepared!",

            // Timestamp related
            timestamp: 1756887225000
        }
    ]

    Component.onCompleted: append(data)
}
