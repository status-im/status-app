## Tests the token-selector producer View's model handle lifecycle: getPreparedModel
## registers a QVariant under a fresh id and reports it via lastPreparedModelId;
## releaseModel forwards to the delegate and drops the tracked QVariant, so the
## model is not kept alive past the modal that owns it.
## Compile -d:QT_MODEL_SPY (needs the seaqt/nimqml toolchain, like the model test).

import unittest

import app/modules/main/wallet_section/token_selector/view
import app/modules/main/wallet_section/token_selector/io_interface
import app/modules/shared_models/token_selector_model

type
  MockDelegate = ref object of AccessInterface
    released: seq[int]
    nextId: int

method createModelForKind(self: MockDelegate, kind: int): tuple[id: int, model: TokenSelectorModel] =
  result = (self.nextId, newTokenSelectorModel())
  self.nextId.inc

method releaseModel(self: MockDelegate, id: int) =
  self.released.add(id)

method viewDidLoad(self: MockDelegate) = discard
method load(self: MockDelegate) = discard
method isLoaded(self: MockDelegate): bool = true
method delete(self: MockDelegate) = discard

suite "TokenSelector producer View - model handle lifecycle":

  test "each prepared model is tracked under a fresh id and reported":
    let d = MockDelegate()
    let v = newView(d)
    v.prepareModel(0)
    discard v.getPreparedModel()
    check v.getLastPreparedModelId() == 0
    v.prepareModel(1)
    discard v.getPreparedModel()
    check v.getLastPreparedModelId() == 1
    check v.trackedModelIdsForTest().len == 2

  test "releaseModel forwards to the delegate and drops the tracked variant":
    let d = MockDelegate()
    let v = newView(d)
    v.prepareModel(0); discard v.getPreparedModel()   # id 0
    v.prepareModel(1); discard v.getPreparedModel()   # id 1
    v.releaseModel(0)
    check d.released == @[0]
    check v.trackedModelIdsForTest() == @[1]           # only the un-released one remains

  test "releasing an unknown id is a no-op on tracking":
    let d = MockDelegate()
    let v = newView(d)
    v.prepareModel(0); discard v.getPreparedModel()
    v.releaseModel(99)
    check v.trackedModelIdsForTest() == @[0]
