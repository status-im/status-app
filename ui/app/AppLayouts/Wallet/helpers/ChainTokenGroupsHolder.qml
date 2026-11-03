import QtQml

import StatusQ.Core.Utils

import AppLayouts.Wallet.stores

// Keeps a chain's token groups loaded while it exists and is active, and exposes
// the chain's model, the same instance for every holder of the chain. The groups
// load on their first holder and are dropped about two minutes after their last
// one goes.
QObject {
    id: root

    required property TokensStore tokensStore

    property int chainId
    property bool active: true
    /** group keys the model loads first, joined by "$$"; read when the chain is
        acquired, empty for the defaults **/
    property string mandatoryKeys

    readonly property bool holding: holder.holding
    /** the held chain's token groups, see TokensStore.chainTokenGroupsModel **/
    readonly property var model: d.model
    readonly property bool loading: !!d.model && d.model.loading

    QtObject {
        id: d

        property var model: null
        property string heldKeys
    }

    ResourceHolder {
        id: holder

        key: root.chainId > 0 ? String(root.chainId) : ""
        active: root.active

        onAcquireRequested: key => {
            const chainId = parseInt(key)
            d.heldKeys = root.mandatoryKeys
            root.tokensStore.acquireChainTokenGroups(chainId, d.heldKeys)
            d.model = root.tokensStore.chainTokenGroupsModel(chainId)
        }
        onReleaseRequested: key => {
            // the store is gone only while the whole app tears down
            root.tokensStore?.releaseChainTokenGroups(parseInt(key), d.heldKeys)
            // on a chain switch the released model stays valid until the next
            // one replaces it, so consumers see no null in between
            if (root.chainId <= 0 || !root.active)
                d.model = null
        }
    }
}
