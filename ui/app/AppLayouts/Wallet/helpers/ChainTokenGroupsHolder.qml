import QtQml

import StatusQ.Core.Utils

import AppLayouts.Wallet.stores

// Keeps a chain's token groups loaded while it exists and is active. The groups
// load on their first holder and are dropped about two minutes after their last
// one goes.
QObject {
    id: root

    required property TokensStore tokensStore

    property int chainId
    property bool active: true

    readonly property bool holding: holder.holding

    ResourceHolder {
        id: holder

        key: root.chainId > 0 ? String(root.chainId) : ""
        active: root.active

        onAcquireRequested: key => root.tokensStore.acquireChainTokenGroups(parseInt(key))
        // the store is gone only while the whole app tears down
        onReleaseRequested: key => root.tokensStore?.releaseChainTokenGroups(parseInt(key))
    }
}
