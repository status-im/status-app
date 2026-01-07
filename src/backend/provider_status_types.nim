import json, strutils, std/strformat, tables

include app_service/common/json_utils

import json_serialization
#export safe_json_serialization
#import json_serialization/std/tables as ser_tables # Needed to serialize tables inside objects

# Mirrors healthmanager/rpcstatus/provider_status.go StatusType
type StateValue* {.pure.} = enum
    Unknown = "unknown"
    Up = "up"
    Down = "down"

# Mirrors healthmanager/rpcstatus/provider_status.go ProviderStatus
type ProviderStatus* = ref object of RootObj
    name*: string
    lastSuccessAt*: int
    lastErrorAt*: int
    lastError*: string
    status*: StateValue
    totalDuration*: int
    totalRequests*: int
    totalTimeoutCount*: int
    totalErrorCount*: int

proc fromJson*(T: type ProviderStatus, json: JsonNode): ProviderStatus =
  result = ProviderStatus()
  result.name = json["name"].getStr()
  result.lastSuccessAt = json["last_success_at"].getInt()
  result.lastErrorAt = json["last_error_at"].getInt()
  if json.hasKey("last_error"):
    result.lastError = json["last_error"].getStr()
  result.status = parseEnum[StateValue](json["status"].getStr())
  result.totalDuration = json["total_duration_ms"].getInt()
  result.totalRequests = json["total_requests"].getInt()
  result.totalTimeoutCount = json["total_timeout_count"].getInt()
  result.totalErrorCount = json["total_error_count"].getInt()

proc `$`*(self: ProviderStatus): string =
  return fmt"""ProviderStatus(
    name:{self.name},
    lastSuccessAt:{self.lastSuccessAt},
    lastErrorAt:{self.lastErrorAt},
    lastError:{self.lastError},
    status:{self.status},
    totalDuration:{self.totalDuration},
    totalRequests:{self.totalRequests},
    totalTimeoutCount:{self.totalTimeoutCount},
    totalErrorCount:{self.totalErrorCount}
  )"""

# Mirrors healthmanager/rpcstatus/provider_status.go BlockchainFullStatus
type BlockchainFullStatus* = ref object of RootObj
    status*: ProviderStatus
    statusPerChain*: Table[int, ProviderStatus]
    statusPerChainPerProvider*: Table[int, Table[string, ProviderStatus]]


proc `$`*(self: BlockchainFullStatus): string =
  return fmt"""BlockchainFullStatus(
    status:{self.status},
    statusPerChain:{self.statusPerChain},
    statusPerChainPerProvider:{self.statusPerChainPerProvider}
  )"""

proc fromJson*(T: type BlockchainFullStatus, json: JsonNode): BlockchainFullStatus =
  result = BlockchainFullStatus()
  result.status = ProviderStatus.fromJson(json["status"])
  result.statusPerChain = initTable[int, ProviderStatus]()
  for chain, status in json["statusPerChain"].pairs:
    let chainInt = parseInt(chain)
    result.statusPerChain[chainInt] = ProviderStatus.fromJson(status)
  result.statusPerChainPerProvider = initTable[int, Table[string, ProviderStatus]]()
  for chain, statusPerProvider in json["statusPerChainPerProvider"].pairs:
    let chainInt = parseInt(chain)
    result.statusPerChainPerProvider[chainInt] = initTable[string, ProviderStatus]()
    for provider, status in statusPerProvider.pairs:
      result.statusPerChainPerProvider[chainInt][provider] = ProviderStatus.fromJson(status)



