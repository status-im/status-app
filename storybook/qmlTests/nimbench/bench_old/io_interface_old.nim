# Verbatim copy of the master version of
# src/app/modules/main/wallet_section/assets/io_interface.nim
# (the OLD `var seq[T]` data source signature).
#
# Renamed with `Old` suffix to coexist with the NEW interface in the same
# bench lib.

import ./asset_group_item_old

type
  GroupedAccountAssetsDataSourceOld* = tuple[
    getGroupedAssetsList: proc(): var seq[AssetGroupItemOld]
  ]
