import std/[sets, tables]
import stint

import app/modules/shared_models/token_list_item
import app_service/common/types
import app_service/service/community/dto/community
import app_service/service/community_tokens/dto/community_token

proc communityTokenRow*(token: CommunityTokensMetadataDto, communityId: string,
    communityTokens: seq[CommunityTokenDto]): TokenListItem =
  # Set fallback supply to infinite in case we don't have it
  var supply = "1"
  var infiniteSupply = true
  var privilegesLevel = PrivilegesLevel.Community.int
  for communityToken in communityTokens:
    if communityToken.symbol == token.symbol and communityToken.communityId == communityId:
      supply = communityToken.supply.toString(10)
      infiniteSupply = communityToken.infiniteSupply
      privilegesLevel = communityToken.privilegesLevel.int
      break
  let communityTokenDecimals = if token.tokenType == TokenType.ERC20: 18 else: 0
  result = initTokenListItem(
    key = token.getContractIdFromFirstAddress(),
    name = token.name,
    symbol = token.symbol,
    color = "", # community tokens don't have `color`
    image = token.image,
    category = ord(TokenListItemCategory.Community),
    communityId = communityId,
    supply,
    infiniteSupply,
    communityTokenDecimals,
    privilegesLevel
  )

proc droppedCommunityTokenRows*[S](dropped: HashSet[(string, string)], source: S): seq[TokenListItem] =
  ## The ERC20 rows of the communities whose wallet rows `dropped` names; only
  ## those communities are read. `source` has getCommunityById and getCommunityTokens.
  var symbolsByCommunity = initTable[string, HashSet[string]]()
  for (symbol, communityId) in dropped:
    symbolsByCommunity.mgetOrPut(communityId, initHashSet[string]()).incl(symbol)
  for communityId, symbols in symbolsByCommunity:
    let community {.cursor.} = source.getCommunityById(communityId)
    var communityTokens: seq[CommunityTokenDto]
    var communityTokensRead = false
    for token in community.communityTokensMetadata:
      if token.tokenType != TokenType.ERC20 or token.symbol notin symbols:
        continue
      if not communityTokensRead:
        communityTokens = source.getCommunityTokens(communityId)
        communityTokensRead = true
      result.add(communityTokenRow(token, communityId, communityTokens))
