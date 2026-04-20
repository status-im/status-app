# Minimal in-memory stand-in for the wallet_account service - NEW variant.
#
# Owns a `CowSeq[AssetGroupItem]` and exposes a closure-based data source
# matching the NEW `GroupedAccountAssetsDataSource` tuple shape.

import stint
import app/core/cow_seq
import app_service/service/wallet_account/dto/asset_group_item
import app/modules/main/wallet_section/assets/io_interface

type
  BenchServiceNew* = ref object
    groupedAssets*: CowSeq[AssetGroupItem]

proc newBenchServiceNew*(): BenchServiceNew =
  result = BenchServiceNew(groupedAssets: toCowSeq(newSeq[AssetGroupItem](0)))

proc dataSource*(self: BenchServiceNew): GroupedAccountAssetsDataSource =
  let svc = self
  return (
    getGroupedAssetsList: proc(): CowSeq[AssetGroupItem] = svc.groupedAssets
  )

proc clear*(self: BenchServiceNew) =
  self.groupedAssets = toCowSeq(newSeq[AssetGroupItem](0))

proc populate*(self: BenchServiceNew, numTokens, numAccounts, numChains: int) =
  ## Same shape as BenchServiceOld.populate so the inputs are identical
  ## across the two model variants.
  var working: seq[AssetGroupItem] = @[]
  for t in 0 ..< numTokens:
    var item = AssetGroupItem(
      key: "token-" & $t,
      balancesPerAccount: @[]
    )
    for a in 0 ..< numAccounts:
      for c in 0 ..< numChains:
        item.balancesPerAccount.add(BalanceItem(
          account: "0xacct" & $a,
          groupKey: "token-" & $t,
          tokenKey: "token-" & $t & "-chain-" & $c,
          chainId: c + 1,
          tokenAddress: "0xaddr" & $t & "-" & $c,
          balance: u256(t * 1000 + a * 100 + c)
        ))
    working.add(item)

  # Atomic swap - this is the CoW invariant the production service uses too.
  self.groupedAssets = toCowSeq(working)

proc bumpSingleBalance*(self: BenchServiceNew) =
  ## Mirrors BenchServiceOld.bumpSingleBalance but goes through CoW: rebuild
  ## the seq, mutate the first balance, swap into a fresh CowSeq.  This
  ## matches what the production token service does on a balance tick.
  var working = self.groupedAssets.asSeq()
  if working.len == 0:
    return
  if working[0].balancesPerAccount.len == 0:
    return
  working[0].balancesPerAccount[0].balance = working[0].balancesPerAccount[0].balance + u256(1)
  self.groupedAssets = toCowSeq(working)
