include app_service/common/json_utils
include app/core/tasks/common

import backend/following_addresses
import std/strformat
import chronicles

logScope:
  topics = "following-address-async-tasks"

type
  FetchFollowingAddressesTaskArg = ref object of QObjectTaskArg
    userAddress: string
    search: string
    limit: int
    offset: int

proc fetchFollowingAddressesTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[FetchFollowingAddressesTaskArg](argEncoded)
  var output = %*{
    "followingAddresses": "",
    "userAddress": arg.userAddress,
    "search": arg.search,
    "error": ""
  }
  try:
    let response = following_addresses.getFollowingAddresses(arg.userAddress, arg.search, arg.limit, arg.offset)
    output["followingAddresses"] = %*response
  except Exception as e:
    output["error"] = %* fmt"Error fetching following addresses: {e.msg}"
  arg.finish(output)
