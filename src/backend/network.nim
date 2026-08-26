import json
import ./core, ./response_type
from ./gen import rpc

import backend/network_types

export response_type, network_types

rpc(getFlatEthereumChains, "networks"):
  discard

rpc(addEthereumChain, "networks"):
  network: NetworkDto

rpc(deleteEthereumChain, "networks"):
  chainId: int

rpc(setChainActive, "networks"):
  chainId: int
  active: bool

rpc(fetchChainIDForURL, "wallet"):
  url: string

rpc(setChainEnabled, "networks"):
  chainId: int
  enabled: bool

rpc(setChainUserRpcProviders, "networks"):
  chainId: int
  rpcProviders: seq[RpcProviderDto]