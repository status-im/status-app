import algorithm
import sequtils
import strutils

import app_service/common/types as common_types

import ./token

export token

# {.acyclic.}: a group holds a seq of (acyclic) TokenItems and no back-edge, so it is
# tree-shaped — ORC must skip cycle tracking (rememberCycle), which crashed on
# Android arm64 for worker-built graphs applied on the GUI thread.
type TokenGroupItem* {.acyclic.} = ref object of RootObj
  key*: string
  name*: string
  symbol*: string
  decimals*: int
  logoUri*: string
  tokens*: seq[TokenItem]

# Group token type is the type of the first token in the group
proc `type`*(self: TokenGroupItem): common_types.TokenType =
  if self.tokens.len == 0:
    return common_types.TokenType.Unknown
  return self.tokens[0].`type`

proc isCommunityTokenGroup*(self: TokenGroupItem): bool =
  self.tokens.anyIt(not it.communityData.id.isEmptyOrWhitespace)

proc addToken*(self: TokenGroupItem, token: TokenItem) =
  if token.isNil:
    raise newException(ValueError, "token is nil")

  if self.key != token.groupKey:
    raise newException(ValueError, "token group key does not match")

  if self.tokens.anyIt(cmpIgnoreCase(it.key, token.key) == 0):
    return

  self.tokens.add(token)

proc sortTokenGroupsByKey*(groups: var seq[TokenGroupItem]) =
  ## Deterministic order by group key. The group source order is
  ## otherwise Nim Table hash order, which rehashes on any set change and
  ## reshuffles survivors for no semantic reason — making setItemsWithSync
  ## reorder pass emit O(n^2) moves on a structural refresh. The visible order is
  ## set downstream by ManageTokensController's saved sort, so this is invisible.
  ## The key here is exactly the getId token_groups_model passes to setItemsWithSync.
  groups.sort(proc(a, b: TokenGroupItem): int = cmp(a.key, b.key))
