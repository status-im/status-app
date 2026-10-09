import QtQuick

import StatusQ.Core.Utils

import QtModelsToolkit

// Union of the chat's own user list and every contact the local user knows about,
// keyed by pubKey. This is the lookup source for turning the "@0x…" mentions on the
// wire into display names, and it is deliberately wider than the chat itself: a
// message may mention somebody who is not in this chat (and, in a 1:1, not even a
// mutual contact), and such a mention must still render as a name rather than a raw
// chat key.
//
// Members come first, so a name the chat itself knows wins over a contact entry. The
// local user is appended last, because neither of the other two sources carries them:
// the Nim contacts model leaves the local user out, and in a 1:1 the chat's users are
// the mutual contacts. Without that row, being mentioned yourself in a DM shows you
// your own chat key.
QObject {
    id: root

    // The chat's own users: channel/group members, or the mutual contacts standing in
    // for them in a 1:1. Needs the `pubKey` and `preferredDisplayName` roles.
    property var chatUsersModel

    // Every contact known locally, mutual or not (RootStore.contactsModel). Same roles.
    property var contactsModel

    // The local user, for mentions of themselves. No row is added while the key is empty.
    property string selfPubKey
    property string selfDisplayName

    // output model
    readonly property alias model: concatModel

    // One row, tracking the local user's name
    ObjectProxyModel {
        id: selfModel

        sourceModel: ListModel {
            ListElement {
                _: "" // empty role to prevent warning
            }
        }

        delegate: QtObject {
            readonly property string pubKey: root.selfPubKey
            readonly property string preferredDisplayName: root.selfDisplayName
        }

        exposedRoles: concatModel.expectedRoles
    }

    ConcatModel {
        id: concatModel

        sources: [
            SourceModel {
                model: root.chatUsersModel ?? null
            },
            SourceModel {
                model: root.contactsModel ?? null
            },
            SourceModel {
                model: root.selfPubKey ? selfModel : null
            }
        ]
        markerRoleName: ""
        expectedRoles: ["pubKey", "preferredDisplayName"]
    }
}
