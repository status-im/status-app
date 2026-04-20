import app_service/service/wallet_account/dto/asset_group_item
import app/core/cow_seq

type
  GroupedAccountAssetsDataSource* = tuple[
    # Returns a CoW snapshot of the grouped assets.  The model holds onto
    # the snapshot until its next modelsUpdated() call so that it can diff
    # the previous and next states.
    getGroupedAssetsList: proc(): CowSeq[AssetGroupItem]
  ]

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj
  ## Abstract class for any input/interaction with this module.

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method load*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method isLoaded*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method getGroupedAccountAssetsDataSource*(self: AccessInterface): GroupedAccountAssetsDataSource {.base.} =
  raise newException(ValueError, "No implementation available")

# View Delegate Interface
# Delegate for the view must be declared here due to use of QtObject and multi
# inheritance, which is not well supported in Nim.
method viewDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method filterChanged*(self: AccessInterface, addresses: seq[string], chainIds: seq[int]) {.base.} =
  raise newException(ValueError, "No implementation available")
