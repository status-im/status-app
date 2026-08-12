import std/[strformat, options], json_serialization, json_serialization/std/options as json_options

export options, json_options

type CommunityDataDto* = object
  id* {.serializedFieldName("id").}: string
  name* {.serializedFieldName("name").}: string
  color* {.serializedFieldName("color").}: string
  image* {.serializedFieldName("image").}: string

type TokenDetailsDto* = object
  description* {.serializedFieldName("Description").}: string
  assetWebsiteUrl* {.serializedFieldName("AssetWebsiteUrl").}: string

type TokenDto* = object
  crossChainId* {.serializedFieldName("crossChainId").}: string
  address* {.serializedFieldName("address").}: string
  name* {.serializedFieldName("name").}: string
  symbol* {.serializedFieldName("symbol").}: string
  decimals* {.serializedFieldName("decimals").}: int
  chainId* {.serializedFieldName("chainId").}: int
  logoUri* {.serializedFieldName("logoUri").}: string
  customToken* {.serializedFieldName("custom").}: bool
  communityData* {.serializedFieldName("communityData").}: CommunityDataDto
  soulbound* {.serializedFieldName("soulbound").}: bool
  privilegesLevel* {.serializedFieldName("privilegesLevel").}: Option[int] # community token privileges level (0 = owner, 1 = token master, 2 = regular community token), none when the token is not a known community token

type TokenDtoSafe* = TokenDto

proc `$`*(self: CommunityDataDto): string =
  result = fmt"""CommunityDataDto[
    id: {self.id},
    name: {self.name},
    color: {self.color},
    image: {self.image}
  ]"""

proc `$`*(self: TokenDto): string =
  result = fmt"""TokenDto[
    crossChainId: {self.crossChainId},
    address: {self.address},
    name: {self.name},
    symbol: {self.symbol},
    decimals: {self.decimals},
    chainId: {self.chainId},
    logoUri: {self.logoUri},
    customToken: {self.customToken},
    communityData: {self.communityData},
    soulbound: {self.soulbound},
    privilegesLevel: {self.privilegesLevel},
    ]"""
