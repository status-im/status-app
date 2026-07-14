// Host integration scene: binds Repeaters to the context-injected
// CollectiblesSelectorModel and its filteredFlatModel and reports the EXACT
// roles the production send modal reads, back to the native `probe`:
//  - flat rows: the roles SimpleSendModal reads off selectedCollectibleEntry.item
//    (uid, tokenType, balance, communityId, collectionUid, name, imageUrl, mediaUrl)
//  - grouped rows: what SearchableCollectiblesPanel's top-level delegate reads
//    (groupName, type, icon, imageUrl||mediaUrl thumbnail, subitems count)
// This proves the QML<->Nim role contract host-side, without the full app.

import QtQuick

Item {
    id: root

    Repeater {
        model: collectiblesModel.filteredFlatModel
        delegate: Item {
            Component.onCompleted: probe.recordFlat(
                model.key, model.uid, model.tokenType, model.balance,
                model.communityId, model.collectionUid, model.name,
                "" + model.imageUrl, "" + model.mediaUrl)
        }
    }

    Repeater {
        model: collectiblesModel
        delegate: Item {
            Component.onCompleted: probe.recordGrouped(
                model.key, model.groupName, model.type,
                "" + model.icon, "" + model.imageUrl, "" + model.mediaUrl,
                model.subitems ? model.subitems.count : 0)
        }
    }

    Timer {
        interval: 50
        running: true
        repeat: false
        onTriggered: probe.onReady()
    }
}
