import unittest

import stint, strutils, random, options, sequtils
import nimqml

import backend/collectibles_types
import app/modules/shared_models/collectibles_model
import app/modules/shared_models/collectibles_entry
import app/modules/shared_models/collectible_ownership_model

# Observes Model.itemsDataUpdated, the signal the views listen to in order to
# re-read entries whose data changed in place.
QtObject:
  type ItemsDataUpdatedSpy = ref object of QObject
    count: int

  proc delete(self: ItemsDataUpdatedSpy)

  proc onItemsDataUpdated*(self: ItemsDataUpdatedSpy) {.slot.} =
    inc self.count

  proc newItemsDataUpdatedSpy(): ItemsDataUpdatedSpy =
    new(result, delete)
    result.QObject.setup

  proc delete(self: ItemsDataUpdatedSpy) =
    self.QObject.delete

proc createTestCollectible(seed: int): CollectiblesEntry =
    let data = Collectible(
        dataType: UniqueID,
        id: CollectibleUniqueID(
            contractID: ContractID(
                address: seed.toHex,
                chainID: seed mod 4
            ),
            tokenID: u256(seed)
        )
    )
    let extradata = ExtraData(
        networkShortName: "Chain" & seed.toHex,
        networkColor: "Color" & seed.toHex,
        networkIconURL: "URL" & seed.toHex,
    )
    return newCollectibleDetailsFullEntry(data, extradata)

proc createTestCollectibles(seed: int, count: int): seq[CollectiblesEntry] =
    result = @[]
    for i in 0..<count:
        result.add(createTestCollectible(seed + i))

proc balances(entries: varargs[(string, int, int)]): seq[AccountBalance] =
    result = @[]
    for e in entries:
        result.add(AccountBalance(address: e[0], balance: u256(e[1]), txTimestamp: e[2]))

# Same shape as createTestCollectible, but with the ownership submodel data
# (owning accounts + their balances) the backend refreshes independently of the
# collectible metadata.
proc createOwnedCollectible(seed: int, ownership: seq[AccountBalance]): CollectiblesEntry =
    let data = Collectible(
        dataType: UniqueID,
        id: CollectibleUniqueID(
            contractID: ContractID(
                address: seed.toHex,
                chainID: seed mod 4
            ),
            tokenID: u256(seed)
        ),
        ownership: some(ownership)
    )
    let extradata = ExtraData(
        networkShortName: "Chain" & seed.toHex,
        networkColor: "Color" & seed.toHex,
        networkIconURL: "URL" & seed.toHex,
    )
    return newCollectibleDetailsFullEntry(data, extradata)

suite "collectibles model":
  test "Collectible list set":
    let collectibles = createTestCollectibles(0, 15)
    let moreCollectibles = createTestCollectibles(100, 10)
    let model = newModel()

    model.setItems(collectibles, 0, false)
    check(model.getItems() == collectibles)

    # Wrong offset, should not change the list
    model.setItems(collectibles, 20, false)
    check(model.getItems() == collectibles)

    # Right offset, should append
    model.setItems(moreCollectibles, 15, false)
    check(model.getItems() == collectibles & moreCollectibles)

    # 0 offset, should replace
    model.setItems(moreCollectibles, 0, false)
    check(model.getItems() == moreCollectibles)

  test "Collectible list update":
    let oldCollectibles = createTestCollectibles(0, 15)
    let model = newModel()

    model.updateItems(oldCollectibles)
    check(model.getItems() == oldCollectibles)

    model.updateItems(oldCollectibles)
    check(model.getItems() == oldCollectibles)

    var newCollectibles = oldCollectibles
    newCollectibles.del(0)
    newCollectibles.del(2)
    newCollectibles.del(7)
    for newC in createTestCollectibles(100, 7):
        newCollectibles.add(newC)
    
    var r = initRand(678)
    r.shuffle(newCollectibles)
    
    model.updateItems(newCollectibles)

    for c in model.getItems():
        check(c in newCollectibles)
    
    for c in newCollectibles:
        check(c in model.getItems())
    
    model.updateItems(@[])
    check(model.getItems().len == 0)

suite "collectibles model - ownership refresh of kept entries":
  test "a kept entry exposes the refreshed ownership and announces it":
    let model = newModel()
    let spy = newItemsDataUpdatedSpy()
    discard QObject.connect(model, itemsDataUpdated, spy, onItemsDataUpdated)

    let original = createOwnedCollectible(1, balances(("0xAAA", 1, 100)))
    model.updateItems(@[original])
    check(model.getItems().len == 1)
    # First population is an append, not an in-place data update.
    check(spy.count == 0)

    # Same collectible ID, but the backend now reports a bigger balance and a
    # second owning account. Nothing else about the collectible changed.
    let refreshed = createOwnedCollectible(1, balances(("0xAAA", 3, 200), ("0xBBB", 5, 300)))
    model.updateItems(@[refreshed])

    check(model.getItems().len == 1)
    let kept = model.getItems()[0]
    # The entry object itself is kept - no tile churn for an unchanged ID.
    check(kept == original)

    # ...but its ownership data must be the refreshed one, otherwise the UI
    # keeps showing stale balance tags and picks the wrong account when sending.
    let ownership = kept.getOwnership()
    check(ownership.mapIt(it.address) == @["0xAAA", "0xBBB"])
    check(ownership.mapIt(it.balance) == @[u256(3), u256(5)])
    check(ownership.mapIt(it.txTimestamp) == @[200, 300])

    # The submodel behind the Ownership role is what QML actually reads.
    check(kept.getOwnershipModel().getBalance("0xAAA") == u256(3))
    check(kept.getOwnershipModel().getBalance("0xBBB") == u256(5))

    # The change has to be announced, or the views never re-read the entry.
    check(spy.count == 1)

  test "an identical refresh reports no change":
    let model = newModel()
    let spy = newItemsDataUpdatedSpy()
    discard QObject.connect(model, itemsDataUpdated, spy, onItemsDataUpdated)

    model.updateItems(@[createOwnedCollectible(2, balances(("0xAAA", 7, 111)))])
    check(spy.count == 0)

    # A poll carrying byte-identical data must not be reported as a change,
    # otherwise the grid re-renders (flickers) on every refresh.
    model.updateItems(@[createOwnedCollectible(2, balances(("0xAAA", 7, 111)))])
    check(spy.count == 0)
    check(model.getItems().len == 1)
    check(model.getItems()[0].getOwnership()[0].balance == u256(7))

  test "additions and removals still work around a refreshed kept entry":
    let model = newModel()
    let spy = newItemsDataUpdatedSpy()
    discard QObject.connect(model, itemsDataUpdated, spy, onItemsDataUpdated)

    let a = createOwnedCollectible(10, balances(("0xAAA", 1, 10)))
    let b = createOwnedCollectible(11, balances(("0xAAA", 1, 10)))
    model.updateItems(@[a, b])
    check(model.getItems().len == 2)
    check(spy.count == 0)

    # b is gone, c is new, a is kept but its balance moved.
    let aRefreshed = createOwnedCollectible(10, balances(("0xAAA", 9, 90)))
    let c = createOwnedCollectible(12, balances(("0xBBB", 2, 20)))
    model.updateItems(@[aRefreshed, c])

    let ids = model.getItems().mapIt(it.getIDAsString())
    check(ids.len == 2)
    check(a.getIDAsString() in ids)
    check(c.getIDAsString() in ids)
    check(not (b.getIDAsString() in ids))

    check(model.getItemById(a.getIDAsString()).getOwnership().mapIt(it.balance) == @[u256(9)])
    check(model.getItemById(c.getIDAsString()).getOwnership().mapIt(it.address) == @["0xBBB"])
    check(spy.count == 1)
