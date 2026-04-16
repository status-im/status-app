import strutils

import app_service/common/types as common_types

import ./token

export token

type TokenGroupItem* = ref object of RootObj
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
  for token in self.tokens:
    if not token.communityData.id.isEmptyOrWhitespace:
      return true
  return false

proc addToken*(self: TokenGroupItem, token: TokenItem) =
  if token.isNil:
    raise newException(ValueError, "token is nil")

  if self.key != token.groupKey:
    raise newException(ValueError, "token group key does not match")

  for t in self.tokens:
    if cmpIgnoreCase(t.key, token.key) == 0:
      return

  self.tokens.add(token)
