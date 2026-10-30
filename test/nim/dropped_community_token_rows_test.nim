## A community's own token row comes back when the wallet row that stood in for
## it goes; only the communities those rows belong to are read.

import std/[unittest, sets, tables, sequtils]

import app/modules/shared_models/token_list_item
import app/modules/main/communities/community_token_rows
import app_service/common/types
import app_service/service/community/dto/community
import app_service/service/community_tokens/dto/community_token

type FakeSource = ref object
  communities: Table[string, CommunityDto]
  emptyCommunity: CommunityDto
  communityReads: seq[string]
  tokenReads: seq[string]

proc getCommunityById(self: FakeSource, communityId: string): lent CommunityDto =
  self.communityReads.add(communityId)
  if not self.communities.hasKey(communityId):
    return self.emptyCommunity
  return self.communities[communityId]

proc getCommunityTokens(self: FakeSource, communityId: string): seq[CommunityTokenDto] =
  self.tokenReads.add(communityId)
  @[CommunityTokenDto(communityId: communityId, symbol: "ctok", infiniteSupply: false,
    privilegesLevel: PrivilegesLevel.Owner)]

proc metadata(symbol: string, tokenType: TokenType): CommunityTokensMetadataDto =
  CommunityTokensMetadataDto(symbol: symbol, name: symbol, tokenType: tokenType,
    addresses: {1: "0x01"}.toTable)

proc source(): FakeSource =
  FakeSource(communities: {
    "c1": CommunityDto(id: "c1", communityTokensMetadata: @[metadata("untouched", TokenType.ERC20)]),
    "c2": CommunityDto(id: "c2", communityTokensMetadata: @[metadata("ctok", TokenType.ERC20),
      metadata("listed", TokenType.ERC20), metadata("nft", TokenType.ERC721)]),
  }.toTable)

suite "dropped community token rows":

  test "nothing dropped reads no community":
    let src = source()
    check droppedCommunityTokenRows(initHashSet[(string, string)](), src).len == 0
    check src.communityReads.len == 0
    check src.tokenReads.len == 0

  test "a dropped row brings back only that community's token":
    let src = source()
    let rows = droppedCommunityTokenRows(toHashSet([("ctok", "c2")]), src)
    check rows.mapIt((it.symbol, it.communityId)) == @[("ctok", "c2")]
    check rows[0].category == ord(TokenListItemCategory.Community)
    check rows[0].privilegesLevel == PrivilegesLevel.Owner.int
    check src.communityReads == @["c2"]
    check src.tokenReads == @["c2"]

  test "a dropped symbol the community does not list as a token adds nothing":
    let src = source()
    check droppedCommunityTokenRows(toHashSet([("nft", "c2"), ("gone", "c2")]), src).len == 0
    check src.communityReads == @["c2"]

  test "a community no longer known is skipped":
    let src = source()
    check droppedCommunityTokenRows(toHashSet([("ctok", "c9")]), src).len == 0
    check src.tokenReads.len == 0

suite "community token row":

  test "each community's row takes its own token values when communities share a symbol":
    let tokens = @[
      CommunityTokenDto(communityId: "c1", symbol: "ctok", infiniteSupply: false,
        privilegesLevel: PrivilegesLevel.Owner),
      CommunityTokenDto(communityId: "c2", symbol: "ctok", infiniteSupply: true,
        privilegesLevel: PrivilegesLevel.Master)]
    let first = communityTokenRow(metadata("ctok", TokenType.ERC20), "c1", tokens)
    let second = communityTokenRow(metadata("ctok", TokenType.ERC20), "c2", tokens)
    check first.privilegesLevel == PrivilegesLevel.Owner.int
    check not first.infiniteSupply
    check second.privilegesLevel == PrivilegesLevel.Master.int
    check second.infiniteSupply

  test "a token of another community alone leaves the fallback values":
    let tokens = @[CommunityTokenDto(communityId: "c2", symbol: "ctok", infiniteSupply: false,
      privilegesLevel: PrivilegesLevel.Owner)]
    let row = communityTokenRow(metadata("ctok", TokenType.ERC20), "c1", tokens)
    check row.privilegesLevel == PrivilegesLevel.Community.int
    check row.infiniteSupply
