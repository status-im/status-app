import sequtils, sugar

import app_service/common/utils as common_utils

import ../dto/token_list
import token

export token


type VersionItem = VersionDto

proc `$`*(self: VersionItem): string =
  return $self.major & "." & $self.minor & "." & $self.patch

# {.acyclic.}: tree-shaped (value fields + a seq of acyclic TokenItems), so ORC skips
# cycle tracking — see the token.nim / token_group.nim note.
type TokenListItemObj {.acyclic.} = object of RootObj
  id: string
  name: string
  timestamp: int64
  fetchedTimestamp: int64
  source: string
  version: VersionItem
  logoUri: string
  tokens: seq[TokenItem]

# TokenListItem creation is enforced using `createTokenListItem`
type TokenListItem* = ref TokenListItemObj

proc id*(t: TokenListItem): string = t.id
proc name*(t: TokenListItem): string = t.name
proc timestamp*(t: TokenListItem): int64 = t.timestamp
proc fetchedTimestamp*(t: TokenListItem): int64 = t.fetchedTimestamp
proc source*(t: TokenListItem): string = t.source
proc version*(t: TokenListItem): string = $t.version
proc logoUri*(t: TokenListItem): string = t.logoUri
proc tokens*(t: TokenListItem): var seq[TokenItem] = t.tokens

proc createTokenListItem*(tlDto: TokenListDto): TokenListItem =
  return TokenListItem(
    id: tlDto.id,
    name: tlDto.name,
    timestamp: common_utils.timestampToUnix(tlDto.timestamp),
    fetchedTimestamp: common_utils.timestampToUnix(tlDto.fetchedTimestamp),
    source: tlDto.source,
    version: VersionItem(
      major: tlDto.version.major,
      minor: tlDto.version.minor,
      patch: tlDto.version.patch
    ),
    logoUri: common_utils.resolveUri(tlDto.logoUri),
    tokens: tlDto.tokens.map(t => createTokenItem(t))
  )