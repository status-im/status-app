import unittest

import app_service/service/network/types
import app/modules/main/wallet_section/send/[network_route_model, network_route_item, suggested_route_item]
import app/modules/shared_models/currency_amount

proc createTokenBalance(amount: float64 = 1.0, symbol: string = "ETH"): CurrencyAmount =
  return newCurrencyAmount(amount, symbol, symbol, 18, true)

proc createNetworkRouteItem(
    chainId: int,
    layer: int = NETWORK_LAYER_1,
    isRouteEnabled: bool = true,
    isRoutePreferred: bool = true,
    hasGas: bool = true,
    tokenBalance: CurrencyAmount = createTokenBalance(),
    amountIn: string = "",
    amountOut: string = "",
    toNetworks: seq[int] = @[],
  ): NetworkRouteItem =
  return initNetworkRouteItem(
    chainId = chainId,
    layer = layer,
    isRouteEnabled = isRouteEnabled,
    isRoutePreferred = isRoutePreferred,
    hasGas = hasGas,
    tokenBalance = tokenBalance,
    amountIn = amountIn,
    amountOut = amountOut,
    toNetworks = toNetworks,
  )

proc createSuggestedRouteItem(
    fromNetwork: int,
    toNetwork: int,
    amountIn: string = "100",
    amountOut: string = "200",
  ): SuggestedRouteItem =
  return newSuggestedRouteItem(
    fromNetwork = fromNetwork,
    toNetwork = toNetwork,
    amountIn = amountIn,
    amountOut = amountOut,
  )

suite "network route model":
  test "set items exposes row count and chain ids":
    let model = newNetworkRouteModel()
    model.setItems(@[
      createNetworkRouteItem(1),
      createNetworkRouteItem(10, layer = NETWORK_LAYER_2),
    ])

    check(model.rowCount() == 2)
    check(model.getAllNetworksChainIds() == @[1, 10])

  test "update from networks accumulates destinations and gas state":
    let model = newNetworkRouteModel()
    model.setItems(@[
      createNetworkRouteItem(1),
      createNetworkRouteItem(10),
      createNetworkRouteItem(100),
    ])

    model.updateFromNetworks(createSuggestedRouteItem(fromNetwork = 1, toNetwork = 10, amountIn = "15"), hasGas = false)
    model.updateFromNetworks(createSuggestedRouteItem(fromNetwork = 1, toNetwork = 100, amountIn = "20"), hasGas = true)

    check(model.items[0].amountIn() == "20")
    check(model.items[0].toNetworks() == "10:100")
    check(model.items[0].hasGas() == true)
    check(model.items[1].amountIn() == "")
    check(model.items[1].toNetworks() == "")

  test "update to networks sums amount out":
    let model = newNetworkRouteModel()
    model.setItems(@[
      createNetworkRouteItem(1),
      createNetworkRouteItem(10),
    ])

    model.updateToNetworks(createSuggestedRouteItem(fromNetwork = 1, toNetwork = 10, amountOut = "25"))
    model.updateToNetworks(createSuggestedRouteItem(fromNetwork = 100, toNetwork = 10, amountOut = "75"))

    check(model.items[0].amountOut() == "")
    check(model.items[1].amountOut() == "100")

  test "update token balance only changes matching chain":
    let model = newNetworkRouteModel()
    let originalBalance = createTokenBalance(1.0, "ETH")
    let updatedBalance = createTokenBalance(5.0, "SNT")
    model.setItems(@[
      createNetworkRouteItem(1, tokenBalance = originalBalance),
      createNetworkRouteItem(10, tokenBalance = originalBalance),
    ])

    model.updateTokenBalanceForSymbol(10, updatedBalance)

    check(model.items[0].getTokenBalance() == originalBalance)
    check(model.items[1].getTokenBalance() == updatedBalance)

  test "preferred chains control enabled state":
    let model = newNetworkRouteModel()
    model.setItems(@[
      createNetworkRouteItem(1, layer = NETWORK_LAYER_1),
      createNetworkRouteItem(10, layer = NETWORK_LAYER_2),
      createNetworkRouteItem(100, layer = NETWORK_LAYER_2),
    ])

    model.updateRoutePreferredChains("10")

    check(model.items[0].isRoutePreferred() == false)
    check(model.items[0].isRouteEnabled() == false)
    check(model.items[1].isRoutePreferred() == true)
    check(model.items[1].isRouteEnabled() == true)
    check(model.items[2].isRoutePreferred() == false)
    check(model.items[2].isRouteEnabled() == false)

    model.enableRouteUnpreferredChains()
    check(model.items[0].isRouteEnabled() == true)
    check(model.items[2].isRouteEnabled() == true)

    model.disableRouteUnpreferredChains()
    check(model.items[0].isRouteEnabled() == false)
    check(model.items[2].isRouteEnabled() == false)

  test "reset clears path data and restores route flags":
    let model = newNetworkRouteModel()
    model.setItems(@[
      createNetworkRouteItem(1, isRouteEnabled = false, isRoutePreferred = false, hasGas = false, amountIn = "10", amountOut = "20", toNetworks = @[10]),
    ])

    model.reset()

    check(model.items[0].amountIn() == "")
    check(model.items[0].amountOut() == "")
    check(model.items[0].toNetworks() == "")
    check(model.items[0].hasGas() == true)
    check(model.items[0].isRouteEnabled() == true)
    check(model.items[0].isRoutePreferred() == true)