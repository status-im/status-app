import json
import constants as main_constants

const ANVIL_NETWORK_ID = 31337

type
  RpcProvider* = object
    chainId*: uint64
    name*: string
    url*: string
    enableRpsLimiter*: bool
    providerType*: string
    enabled*: bool
    authType*: string

  Network* = object
    chainID*: uint64
    chainName*: string
    rpcProviders*: seq[RpcProvider] # List of RPC providers, in the order in which they are accessed
    nativeCurrencyName*: string
    nativeCurrencySymbol*: string
    nativeCurrencyDecimals*: uint64
    isTest*: bool
    layer*: uint64
    enabled*: bool
    # chainColor*: string
    shortName*: string
    # tokenOverrides*: seq[Token] # Assuming Token is defined elsewhere
    # relatedChainID*: uint64
    isActive*: bool
    isDeactivatable*: bool
    # eIP1559Enabled*: bool
    # noBaseFee*: bool
    # noPriorityFee*: bool
    # communitiesSupported*: bool

proc toJson*(self: Network): JsonNode =
  result = %*{
    "chainId": self.chainID,
    "chainName": self.chainName,
    "rpcProviders": self.rpcProviders,
    "nativeCurrencyName": self.nativeCurrencyName,
    "nativeCurrencySymbol": self.nativeCurrencySymbol,
    "nativeCurrencyDecimals": self.nativeCurrencyDecimals,
    "isTest": self.isTest,
    "layer": self.layer,
    "enabled": self.enabled,
    # "chainColor": self.chainColor,
    "shortName": self.shortName,
    # "tokenOverrides": self.tokenOverrides,
    # "relatedChainId": self.relatedChainID,
    "isActive": self.isActive,
    "isDeactivatable": self.isDeactivatable,
    # "eip1559Enabled": self.eIP1559Enabled,
    # "noBaseFee": self.noBaseFee,
    # "noPriorityFee": self.noPriorityFee,
    # "communitiesSupported": self.communitiesSupported,
  }

proc newAnvilNetwork*(): Network =
  result = Network(
    chainID: ANVIL_NETWORK_ID,
    chainName: "Anvil",
    rpcProviders: @[
      RpcProvider(
        chainId: ANVIL_NETWORK_ID,
        name: "Anvil Direct",
        url: main_constants.ANVIL_URL,
        enableRpsLimiter: false,
        providerType: "embedded-direct",
        enabled: true,
        authType: "no-auth"
      )
    ],
    shortName: "eth",
    nativeCurrencyName: "Ether",
    nativeCurrencySymbol: "ETH",
    nativeCurrencyDecimals: 18,
    isTest: false,
    layer: 1,
    enabled: true,
    isActive: true,
    isDeactivatable: false
  )