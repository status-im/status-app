import nimqml, std/strformat
import sequtils, sugar

import backend/network_types
import ./rpc_provider_item

export rpc_provider_item

QtObject:
  type NetworkItem* = ref object of QObject
    chainId*: int
    layer*: int
    chainName*: string
    iconUrl*: string
    shortName*: string
    chainColor*: string
    rpcProviders*: seq[RpcProviderItem]
    blockExplorerURL*: string
    nativeCurrencyName*: string
    nativeCurrencySymbol*: string
    nativeCurrencyDecimals*: int
    isTest*: bool
    isEnabled*: bool
    relatedChainId*: int
    isActive*: bool
    isDeactivatable*: bool
    eip1559Enabled*: bool
    noBaseFee*: bool
    noPriorityFee*: bool
    communitiesSupported*: bool

  proc setup*(self: NetworkItem,
        chainId: int,
        layer: int,
        chainName: string,
        iconUrl: string,
        shortName: string,
        chainColor: string,
        rpcProviders: seq[RpcProviderItem],
        blockExplorerURL: string,
        nativeCurrencyName: string,
        nativeCurrencySymbol: string,
        nativeCurrencyDecimals: int,
        isTest: bool,
        isEnabled: bool,
        relatedChainId: int,
        isActive: bool,
        isDeactivatable: bool,
        eip1559Enabled: bool,
        noBaseFee: bool,
        noPriorityFee: bool,
        communitiesSupported: bool
        )
  proc delete*(self: NetworkItem)
  proc networkDtoToItem*(network: NetworkDto): NetworkItem =
    new(result, delete)
    let rpcProviders = network.rpcProviders.map(p => rpcProviderDtoToItem(p))
    result.setup(network.chainId, network.layer, network.chainName, network.iconUrl, network.shortName,
      network.chainColor, rpcProviders,
      network.blockExplorerURL, network.nativeCurrencyName, network.nativeCurrencySymbol, network.nativeCurrencyDecimals,
      network.isTest, network.isEnabled, network.relatedChainId, network.isActive, network.isDeactivatable,
      network.eip1559Enabled, network.noBaseFee, network.noPriorityFee, network.communitiesSupported)

  proc networkItemToDto*(network: NetworkItem): NetworkDto =
    result = NetworkDto(
      chainId: network.chainId,
      nativeCurrencyDecimals: network.nativeCurrencyDecimals,
      layer: network.layer,
      chainName: network.chainName,
      rpcProviders: network.rpcProviders.map(p => rpcProviderItemToDto(p)),
      blockExplorerURL: network.blockExplorerURL,
      iconUrl: network.iconUrl,
      nativeCurrencyName: network.nativeCurrencyName,
      nativeCurrencySymbol: network.nativeCurrencySymbol,
      isTest: network.isTest,
      isEnabled: network.isEnabled,
      chainColor: network.chainColor,
      shortName: network.shortName,
      relatedChainId: network.relatedChainId,
      isActive: network.isActive,
      isDeactivatable: network.isDeactivatable,
      eip1559Enabled: network.eip1559Enabled,
      noBaseFee: network.noBaseFee,
      noPriorityFee: network.noPriorityFee,
      communitiesSupported: network.communitiesSupported
    )

  proc `$`*(self: NetworkItem): string =
    result = fmt"""NetworkItem(
      chainId: {self.chainId},
      chainName: {self.chainName},
      layer: {self.layer},
      iconUrl:{self.iconUrl},
      shortName: {self.shortName},
      chainColor: {self.chainColor},
      rpcProviders: {self.rpcProviders},
      blockExplorerURL: {self.blockExplorerURL},
      nativeCurrencySymbol: {self.nativeCurrencySymbol},
      nativeCurrencyName: {self.nativeCurrencyName},
      nativeCurrencyDecimals: {self.nativeCurrencyDecimals},
      isTest: {self.isTest},
      isEnabled: {self.isEnabled},
      relatedChainId: {self.relatedChainId},
      isActive: {self.isActive},
      isDeactivatable: {self.isDeactivatable},
      eip1559Enabled: {self.eip1559Enabled},
      noBaseFee: {self.noBaseFee},
      noPriorityFee: {self.noPriorityFee},
      communitiesSupported: {self.communitiesSupported}
      ]"""

  proc chainId*(self: NetworkItem): int {.slot.} =
    return self.chainId
  QtProperty[int] chainId:
    read = chainId

  proc layer*(self: NetworkItem): int {.slot.} =
    return self.layer
  QtProperty[int] layer:
    read = layer

  proc chainName*(self: NetworkItem): string {.slot.} =
    return self.chainName
  QtProperty[string] chainName:
    read = chainName

  proc iconUrl*(self: NetworkItem): string {.slot.} =
    return self.iconUrl
  QtProperty[string] iconUrl:
    read = iconUrl

  proc shortName*(self: NetworkItem): string {.slot.} =
    return self.shortName
  QtProperty[string] shortName:
    read = shortName

  proc chainColor*(self: NetworkItem): string {.slot.} =
    return self.chainColor
  QtProperty[string] chainColor:
    read = chainColor

  proc rpcProviders*(self: NetworkItem): seq[RpcProviderItem] =
    return self.rpcProviders

  proc blockExplorerURL*(self: NetworkItem): string {.slot.} =
    return self.blockExplorerURL
  QtProperty[string] blockExplorerURL:
    read = blockExplorerURL

  proc nativeCurrencySymbol*(self: NetworkItem): string {.slot.} =
    return self.nativeCurrencySymbol
  QtProperty[string] nativeCurrencySymbol:
    read = nativeCurrencySymbol

  proc nativeCurrencyName*(self: NetworkItem): string {.slot.} =
    return self.nativeCurrencyName
  QtProperty[string] nativeCurrencyName:
    read = nativeCurrencyName

  proc nativeCurrencyDecimals*(self: NetworkItem): int {.slot.} =
    return self.nativeCurrencyDecimals
  QtProperty[int] nativeCurrencyDecimals:
    read = nativeCurrencyDecimals

  proc isTest*(self: NetworkItem): bool {.slot.} =
    return self.isTest
  QtProperty[bool] isTest:
    read = isTest

  proc isEnabled*(self: NetworkItem): bool {.slot.} =
    return self.isEnabled
  QtProperty[bool] isEnabled:
    read = isEnabled

  proc relatedChainId*(self: NetworkItem): int {.slot.} =
    return self.relatedChainId
  QtProperty[int] relatedChainId:
    read = relatedChainId

  proc isActive*(self: NetworkItem): bool {.slot.} =
    return self.isActive
  QtProperty[bool] isActive:
    read = isActive

  proc communitiesSupported*(self: NetworkItem): bool {.slot.} =
    return self.communitiesSupported
  QtProperty[bool] communitiesSupported:
    read = communitiesSupported

  proc delete*(self: NetworkItem) =
      self.QObject.delete

  proc setup*(self: NetworkItem,
      chainId: int,
      layer: int,
      chainName: string,
      iconUrl: string,
      shortName: string,
      chainColor: string,
      rpcProviders: seq[RpcProviderItem],
      blockExplorerURL: string,
      nativeCurrencyName: string,
      nativeCurrencySymbol: string,
      nativeCurrencyDecimals: int,
      isTest: bool,
      isEnabled: bool,
      relatedChainId: int,
      isActive: bool,
      isDeactivatable: bool,
      eip1559Enabled: bool,
      noBaseFee: bool,
      noPriorityFee: bool,
      communitiesSupported: bool
      ) =
        self.QObject.setup
        self.chainId = chainId
        self.layer = layer
        self.chainName = chainName
        self.iconUrl = iconUrl
        self.shortName = shortName
        self.chainColor = chainColor
        self.rpcProviders = rpcProviders
        self.blockExplorerURL = blockExplorerURL
        self.nativeCurrencyName = nativeCurrencyName
        self.nativeCurrencySymbol = nativeCurrencySymbol
        self.nativeCurrencyDecimals = nativeCurrencyDecimals
        self.isTest = isTest
        self.isEnabled = isEnabled
        self.relatedChainId = relatedChainId
        self.isActive = isActive
        self.isDeactivatable = isDeactivatable
        self.eip1559Enabled = eip1559Enabled
        self.noBaseFee = noBaseFee
        self.noPriorityFee = noPriorityFee
        self.communitiesSupported = communitiesSupported