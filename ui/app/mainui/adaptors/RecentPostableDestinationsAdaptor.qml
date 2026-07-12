import QtQml

import StatusQ.Core.Utils

import SortFilterProxyModel

/**
  * Data-oriented adaptor producing the "recent postable destinations" model
  * (see CONTEXT.md): from a plain model of chats/channels it keeps only the
  * destinations the user can post to (1-1 chats, group chats, community
  * channels with post rights) and orders them by recency of the last message.
  *
  * Expected source roles: canPost (bool), lastMessageTimestamp (int) plus
  * whatever display roles the consumer needs — all source roles pass through.
  * Consumed by the share-flow destination picker; the direct-share shortcut
  * publisher slice reuses it later.
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

        sorters: RoleSorter {
            roleName: "lastMessageTimestamp"
            sortOrder: Qt.DescendingOrder
        }
    }
}
