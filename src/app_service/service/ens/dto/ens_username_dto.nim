{.used.}

import json, std/strformat, hashes
import app_service/service/transaction/dto
include app_service/common/json_utils

type EnsUsernameDto* = ref object
  chainId*: int
  username*: string
  txType*: PendingTransactionTypeDto
  txHash*: string
  txStatus*: string

proc `==`*(l, r: EnsUsernameDto): bool =
    return l.chainId == r.chainid and l.username == r.username

proc `$`*(self: EnsUsernameDto): string =
  result = fmt"""EnsUsernameDto(
    chainId: {self.chainId},
    username: {self.username},
    txType: {self.txType},
    txHash: {self.txHash},
    txStatus: {self.txStatus}
    )"""

proc hash*(dto: EnsUsernameDto): Hash =
    return ($dto).hash

proc toEnsUsernameDto*(jsonObj: JsonNode): EnsUsernameDto =
  result = EnsUsernameDto()
  discard jsonObj.getProp("chainId", result.chainId)
  discard jsonObj.getProp("username", result.username)