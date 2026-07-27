import QtQml

import StatusQ.Core.Utils

import SortFilterProxyModel

/**
  * Data-oriented adaptor producing the "recent postable destinations" model
  * (see CONTEXT.md): from a plain model of chats/channels it keeps only the
  * destinations the user can post to (1-1 chats, group chats, community
  * channels with post rights) and orders them by recency of the user's own
  * last message — the chats the user actually sends to rank first, so a busy
  * channel the user never posts in cannot outrank them. Destinations the user
  * never posted in (lastOwnMessageTimestamp of 0) follow, ordered by recency
  * of the last message from anyone.
  *
  * Expected source roles: canPost (bool), lastOwnMessageTimestamp (int),
  * lastMessageTimestamp (int) plus whatever display roles the consumer needs
  * — all source roles pass through. Consumed by the share-flow destination
  * picker, the direct-share shortcut publisher and the iOS intent donor.
  */
QObject {
    id: root

    property alias sourceModel: proxyModel.sourceModel

    readonly property SortFilterProxyModel model: SortFilterProxyModel {
        id: proxyModel

        filters: ValueFilter {
            roleName: "canPost"
            value: true
        }

        // Descending sort on the own-send timestamp ranks sent-to chats by the
        // user's own recency and ties all never-sent-to chats (timestamp 0) at
        // the bottom, where the secondary sorter falls back to any-message
        // recency.
        sorters: [
            RoleSorter {
                roleName: "lastOwnMessageTimestamp"
                sortOrder: Qt.DescendingOrder
            },
            RoleSorter {
                roleName: "lastMessageTimestamp"
                sortOrder: Qt.DescendingOrder
            }
        ]
    }
}
