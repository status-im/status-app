# Minimal in-memory stand-in for the wallet_account service - OLD variant.
#
# Owns a `seq[AssetGroupItemOld]` and exposes a closure-based data source
# matching the OLD `GroupedAccountAssetsDataSourceOld` tuple shape.
#
# Used by the bench harness to drive the OLD model under controlled,
# deterministic input.

import stint
import ./asset_group_item_old, ./io_interface_old

type
  BenchServiceOld* = ref object
    groupedAssets*: seq[AssetGroupItemOld]

proc newBenchServiceOld*(): BenchServiceOld =
  result = BenchServiceOld(groupedAssets: @[])

proc dataSource*(self: BenchServiceOld): GroupedAccountAssetsDataSourceOld =
  # Capture self by ref so the `var` return points at the live storage.
  let svc = self
  return (
    getGroupedAssetsList: proc(): var seq[AssetGroupItemOld] = svc.groupedAssets
  )

proc clear*(self: BenchServiceOld) =
  self.groupedAssets = @[]

proc populate*(self: BenchServiceOld, numTokens, numAccounts, numChains: int) =
  ## Build a deterministic synthetic dataset.
  self.groupedAssets = @[]
  for t in 0 ..< numTokens:
    let item = AssetGroupItemOld(
      key: "token-" & $t,
      balancesPerAccount: @[]
    )
    for a in 0 ..< numAccounts:
      for c in 0 ..< numChains:
        item.balancesPerAccount.add(BalanceItemOld(
          account: "0xacct" & $a,
          groupKey: "token-" & $t,
          tokenKey: "token-" & $t & "-chain-" & $c,
          chainId: c + 1,
          tokenAddress: "0xaddr" & $t & "-" & $c,
          balance: u256(t * 1000 + a * 100 + c)
        ))
    self.groupedAssets.add(item)

proc bumpSingleBalance*(self: BenchServiceOld) =
  ## Mutate exactly one BalanceItem to simulate a single-row balance tick.
  if self.groupedAssets.len == 0:
    return
  let item = self.groupedAssets[0]
  if item.balancesPerAccount.len == 0:
    return
  item.balancesPerAccount[0].balance += u256(1)
