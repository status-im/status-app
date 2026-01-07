import nimqml, std/strformat, stint

import ./gas_estimate_item, ./suggested_route_model, ./network_route_model, ./io_interface

QtObject:
  type TransactionRoutes* = ref object of QObject
    uuid: string
    suggestedRoutes: SuggestedRouteModel
    gasTimeEstimate: GasEstimateItem
    amountToReceive: UInt256
    toNetworksRouteModel: NetworkRouteModel
    rawPaths: string

  proc setup*(self: TransactionRoutes,
    uuid: string,
    suggestedRoutes: SuggestedRouteModel,
    gasTimeEstimate: GasEstimateItem,
    amountToReceive: UInt256,
    toNetworksRouteModel: NetworkRouteModel,
    rawPaths: string
    )
  proc delete*(self: TransactionRoutes)
  proc newTransactionRoutes*(
    uuid: string = "",
    suggestedRoutes: SuggestedRouteModel = newSuggestedRouteModel(),
    gasTimeEstimate: GasEstimateItem = newGasEstimateItem(),
    amountToReceive: UInt256 = stint.u256(0),
    toNetworksRouteModel: NetworkRouteModel = newNetworkRouteModel(),
    rawPaths: string = ""
    ): TransactionRoutes =
    new(result, delete)
    result.setup(uuid, suggestedRoutes, gasTimeEstimate, amountToReceive, toNetworksRouteModel, rawPaths)

  proc `$`*(self: TransactionRoutes): string =
    result = fmt"""TransactionRoutes(
      uuid: {self.uuid},
      suggestedRoutes: {self.suggestedRoutes},
      gasTimeEstimate: {self.gasTimeEstimate},
      amountToReceive: {self.amountToReceive},
      toNetworksRouteModel: {self.toNetworksRouteModel},
      rawPaths: {self.rawPaths},
      ]"""

  proc uuidChanged*(self: TransactionRoutes) {.signal.}
  proc getUuid*(self: TransactionRoutes): string {.slot.} =
    return self.uuid
  QtProperty[string] uuid:
    read = getUuid
    notify = uuidChanged

  proc suggestedRoutesChanged*(self: TransactionRoutes) {.signal.}
  proc getSuggestedRoutes*(self: TransactionRoutes): QVariant {.slot.} =
    return newQVariant(self.suggestedRoutes)
  QtProperty[QVariant] suggestedRoutes:
    read = getSuggestedRoutes
    notify = suggestedRoutesChanged

  proc gasTimeEstimateChanged*(self: TransactionRoutes) {.signal.}
  proc getGasTimeEstimate*(self: TransactionRoutes): QVariant {.slot.} =
    return newQVariant(self.gasTimeEstimate)
  QtProperty[QVariant] gasTimeEstimate:
    read = getGasTimeEstimate
    notify = gasTimeEstimateChanged

  proc amountToReceiveChanged*(self: TransactionRoutes) {.signal.}
  proc getAmountToReceive*(self: TransactionRoutes): string {.slot.} =
    return self.amountToReceive.toString()
  QtProperty[string] amountToReceive:
    read = getAmountToReceive
    notify = amountToReceiveChanged

  proc toNetworksChanged*(self: TransactionRoutes) {.signal.}
  proc getToNetworks*(self: TransactionRoutes): QVariant {.slot.} =
    return newQVariant(self.toNetworksRouteModel)
  QtProperty[QVariant] toNetworksRouteModel:
    read = getToNetworks
    notify = toNetworksChanged

  proc rawPathsChanged*(self: TransactionRoutes) {.signal.}
  proc getRawPaths*(self: TransactionRoutes): string {.slot.} =
    return self.rawPaths
  QtProperty[string] rawPaths:
    read = getRawPaths
    notify = rawPathsChanged

  proc delete*(self: TransactionRoutes) =
      self.QObject.delete

  proc setup*(self: TransactionRoutes,
    uuid: string,
    suggestedRoutes: SuggestedRouteModel,
    gasTimeEstimate: GasEstimateItem,
    amountToReceive: UInt256,
    toNetworksRouteModel: NetworkRouteModel,
    rawPaths: string
    ) =
      self.QObject.setup
      self.uuid = uuid
      self.suggestedRoutes = suggestedRoutes
      self.gasTimeEstimate = gasTimeEstimate
      self.amountToReceive = amountToReceive
      self.toNetworksRouteModel = toNetworksRouteModel
      self.rawPaths = rawPaths