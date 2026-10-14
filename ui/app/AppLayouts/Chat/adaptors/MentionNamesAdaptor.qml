import QtQuick

import StatusQ.Core.Utils

import QtModelsToolkit
import SortFilterProxyModel

// Union of the chat's own user list and every contact with a name of their own, keyed
// by pubKey. This is the lookup source for turning the "@0x…" mentions on the wire into
// display names, and it is deliberately wider than the chat itself: a message may
// mention somebody who is not in this chat (and, in a 1:1, not even a mutual contact),
// and such a mention must still render as a name rather than a raw chat key.
//
// Members come first, so a name the chat itself knows wins over a contact entry.
// Contacts with only an alias are left out, so the name the message carries
// (MentionResolver's knownNames) is used for them instead. MentionResolver resolves the
// local user itself.
QObject {
    id: root

    // The chat's own users: channel/group members, or the mutual contacts standing in
    // for them in a 1:1. Needs the `pubKey` and `preferredDisplayName` roles.
    property var chatUsersModel

    // Every contact known locally, mutual or not (RootStore.contactsModel). Same roles,
    // plus `usesDefaultName` and `isContact`.
    property var contactsModel

    // output model
    readonly property alias model: concatModel

    SortFilterProxyModel {
        id: namedContacts

        sourceModel: root.contactsModel ?? null

        filters: AnyOf {
            ValueFilter {
                roleName: "usesDefaultName"
                value: false
            }
            ValueFilter {
                roleName: "isContact"
                value: true
            }
        }
    }

    ConcatModel {
        id: concatModel

        sources: [
            SourceModel {
                model: root.chatUsersModel ?? null
            },
            SourceModel {
                model: root.contactsModel ? namedContacts : null
            }
        ]
        markerRoleName: ""
        expectedRoles: ["pubKey", "preferredDisplayName"]
    }
}
