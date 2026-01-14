import json, json_serialization, chronicles, sugar, sequtils

import ../../../app/core/eventemitter
import backend/network as backend
import ../settings/service as settings_service
import ./network_item

import types
export types

logScope:
  topics = "network-service"

const SIGNAL_NETWORK_ENDPOINT_UPDATED* = "networkEndPointUpdated"
const EXPLORER_TX_PATH* = "/tx"
const EXPLORER_ADDRESS_PATH* = "/address"

type NetworkEndpointUpdatedArgs* = ref object of Args
  isTest*: bool
  networkName*: string

type
  Service* = ref object of RootObj
    events: EventEmitter
    flatNetworks: seq[NetworkItem]
    rpcProviders: seq[RpcProviderItem]
    settingsService: settings_service.Service

proc delete*(self: Service) =
  discard

proc newService*(events: EventEmitter, settingsService: settings_service.Service): Service =
  result = Service()
  result.events = events
  result.settingsService = settingsService

proc fetchNetworks(self: Service) =
  let response = backend.getFlatEthereumChains()
  if not response.error.isNil:
    let errDescription = response.error.message
    error "error getting networks: ", errDescription
  let networksDto = if response.result.isNil or response.result.kind == JNull: @[]
            else: Json.decode($response.result, seq[NetworkDtoSafe], allowUnknownFields = true)
  self.flatNetworks = networksDto.map(n => networkDtoToItem(n))
  self.rpcProviders = @[]
  for network in self.flatNetworks:
    self.rpcProviders.add(network.rpcProviders)

proc init*(self: Service) =
  self.fetchNetworks()

proc resetNetworks*(self: Service) =
  self.fetchNetworks()

proc getFlatNetworks*(self: Service): var seq[NetworkItem] =
  return self.flatNetworks

proc getRpcProviders*(self: Service): var seq[RpcProviderItem] =
  return self.rpcProviders

# passes networks based on users choice of test/mainnet and active/inactive
proc getCurrentNetworks*(self: Service): seq[NetworkItem] =
  let testEnabled = self.settingsService.areTestNetworksEnabled()
  self.flatNetworks.filter(n => n.isTest == testEnabled and n.isActive)

proc getCurrentNetworksChainIds*(self: Service): seq[int] =
  return self.getCurrentNetworks().map(n => n.chainId)

proc getEnabledChainIds*(self: Service): seq[int] =
  return self.getCurrentNetworks().filter(n => n.isEnabled).map(n => n.chainId)

proc upsertNetwork*(self: Service, network: NetworkItem): bool =
  let response = backend.addEthereumChain(networkItemToDto(network))
  return response.error == nil

proc deleteNetwork*(self: Service, network: NetworkItem) =
  discard backend.deleteEthereumChain(network.chainId)

proc getNetworkByChainId*(self: Service, chainId: int): NetworkItem =
  if self.flatNetworks.len == 0:
    self.fetchNetworks()
  for network in self.flatNetworks:
    if chainId == network.chainId:
        return network
  return nil

proc setNetworksState*(self: Service, chainIds: seq[int], enabled: bool) =
  for chainId in chainIds:
    let network = self.getNetworkByChainId(chainId)

    if not network.isNil:
      discard backend.setChainEnabled(chainId, enabled)
  self.fetchNetworks()

proc setNetworkActive*(self: Service, chainId: int, active: bool) =
  let network = self.getNetworkByChainId(chainId)

  if not network.isNil and network.isActive != active:
    discard backend.setChainActive(chainId, active)
  self.fetchNetworks()

## This procedure retuns the network to be used based on the app mode (testnet/mainnet).
## We don't need to check if retuned network is nil cause it should never be, but if somehow it is, the app will be closed.
##
## Should be used for:
## - Stickers
## - Chat
## - Activity check
## - Collectibles
## - ENS names
## - Browser
proc getAppNetwork*(self: Service): NetworkItem =
  var networkId = Mainnet
  if self.settingsService.areTestNetworksEnabled():
    networkId = Sepolia
  let network = self.getNetworkByChainId(networkId)
  if network.isNil:
    # we should not be here ever
    error "the app network cannot be resolved"
    quit() # quit the app
  return network

proc updateNetworkEndPointValues*(self: Service, chainId: int, newMainRpcInput, newFailoverRpcUrl: string) =
  let network = self.getNetworkByChainId(chainId)

  if not network.isNil:
    var rpcProviders: seq[RpcProviderDto] = @[]
    if newMainRpcInput != "":
      rpcProviders.add(RpcProviderDto(
        id: 1,
        chainId: chainId,
        name: "user-rpc-provider-1",
        url: newMainRpcInput,
        isRpsLimiterEnabled: false,
        providerType: RpcProviderType.User,
        isEnabled: true,
        authType: RpcProviderAuthType.NoAuth,
        authLogin: "",
        authPassword: "",
        authToken: ""
      ))
    if newFailoverRpcUrl != "":
      rpcProviders.add(RpcProviderDto(
        id: 2,
        chainId: chainId,
        name: "user-rpc-provider-2",
        url: newFailoverRpcUrl,
        isRpsLimiterEnabled: false,
        providerType: RpcProviderType.User,
        isEnabled: true,
        authType: RpcProviderAuthType.NoAuth,
        authLogin: "",
        authPassword: "",
        authToken: ""
      ))
    let response = backend.setChainUserRpcProviders(chainId, rpcProviders)

    if response.error == nil:
      self.fetchNetworks()
      self.events.emit(SIGNAL_NETWORK_ENDPOINT_UPDATED, NetworkEndpointUpdatedArgs(isTest: network.isTest, networkName: network.chainName))
