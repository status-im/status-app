import json, strutils, std/strformat, stint, sequtils, json_serialization

include ../../../common/json_utils
include ../../../common/utils

type ProfileShowcaseVisibility* {.pure.}= enum
  ToNoOne = 0,
  ToIDVerifiedContacts = 1,
  ToContacts = 2,
  ToEveryone = 3,

type ProfileShowcaseCommunityPreference* = ref object of RootObj
  communityId*: string
  showcaseVisibility*: ProfileShowcaseVisibility
  order*: int

type ProfileShowcaseAccountPreference* = ref object of RootObj
  address*: string
  showcaseVisibility*: ProfileShowcaseVisibility
  order*: int

type ProfileShowcaseCollectiblePreference* = ref object of RootObj
  contractAddress*: string
  chainId*: int
  tokenId*: string
  showcaseVisibility*: ProfileShowcaseVisibility
  order*: int

type ProfileShowcaseVerifiedTokenPreference* = ref object of RootObj
  symbol*: string
  showcaseVisibility*: ProfileShowcaseVisibility
  order*: int

type ProfileShowcaseUnverifiedTokenPreference* = ref object of RootObj
  contractAddress*: string
  chainId*: int
  showcaseVisibility*: ProfileShowcaseVisibility
  order*: int

type ProfileShowcaseSocialLinkPreference* = ref object of RootObj
  url*: string
  text*: string
  showcaseVisibility*: ProfileShowcaseVisibility
  order*: int

type ProfileShowcasePreferencesDto* = ref object of RootObj
  communities*: seq[ProfileShowcaseCommunityPreference]
  accounts*: seq[ProfileShowcaseAccountPreference]
  collectibles*: seq[ProfileShowcaseCollectiblePreference]
  verifiedTokens*: seq[ProfileShowcaseVerifiedTokenPreference]
  unverifiedTokens*: seq[ProfileShowcaseUnverifiedTokenPreference]
  socialLinks*: seq[ProfileShowcaseSocialLinkPreference]

proc toProfileShowcaseVisibility*(jsonObj: JsonNode): ProfileShowcaseVisibility =
  var visibilityInt: int
  if (jsonObj.getProp("showcaseVisibility", visibilityInt) and
    (visibilityInt >= ord(low(ProfileShowcaseVisibility)) and
    visibilityInt <= ord(high(ProfileShowcaseVisibility)))):
      return ProfileShowcaseVisibility(visibilityInt)
  return ProfileShowcaseVisibility.ToNoOne

proc toProfileShowcaseCommunityPreference*(jsonObj: JsonNode): ProfileShowcaseCommunityPreference =
  result = ProfileShowcaseCommunityPreference()
  discard jsonObj.getProp("communityId", result.communityId)
  discard jsonObj.getProp("order", result.order)
  result.showcaseVisibility = jsonObj.toProfileShowcaseVisibility()

proc toJsonNode*(self: ProfileShowcaseCommunityPreference): JsonNode =
  %* {
    "communityId": self.communityId,
    "showcaseVisibility": self.showcaseVisibility.int,
    "order": self.order,
  }

proc toProfileShowcaseAccountPreference*(jsonObj: JsonNode): ProfileShowcaseAccountPreference =
  result = ProfileShowcaseAccountPreference()
  discard jsonObj.getProp("address", result.address)
  discard jsonObj.getProp("order", result.order)
  result.showcaseVisibility = jsonObj.toProfileShowcaseVisibility()

proc toJsonNode*(self: ProfileShowcaseAccountPreference): JsonNode =
  %* {
    "address": self.address,
    "showcaseVisibility": self.showcaseVisibility.int,
    "order": self.order,
  }

proc toProfileShowcaseCollectiblePreference*(jsonObj: JsonNode): ProfileShowcaseCollectiblePreference =
  result = ProfileShowcaseCollectiblePreference()
  discard jsonObj.getProp("chainId", result.chainId)
  discard jsonObj.getProp("tokenId", result.tokenId)
  discard jsonObj.getProp("contractAddress", result.contractAddress)
  discard jsonObj.getProp("order", result.order)
  result.showcaseVisibility = jsonObj.toProfileShowcaseVisibility()

proc toJsonNode*(self: ProfileShowcaseCollectiblePreference): JsonNode =
  %* {
    "chainId": self.chainId,
    "tokenId": self.tokenId,
    "contractAddress": self.contractAddress,
    "showcaseVisibility": self.showcaseVisibility.int,
    "order": self.order,
  }

# TODO: refactor to utils function on code cleanup stage
proc toCombinedCollectibleId*(self: ProfileShowcaseCollectiblePreference): string =
  return fmt"{self.chainId}+{self.contractAddress}+{self.tokenId}"

proc toProfileShowcaseVerifiedTokenPreference*(jsonObj: JsonNode): ProfileShowcaseVerifiedTokenPreference =
  result = ProfileShowcaseVerifiedTokenPreference()
  discard jsonObj.getProp("symbol", result.symbol)
  discard jsonObj.getProp("order", result.order)
  result.showcaseVisibility = jsonObj.toProfileShowcaseVisibility()

proc toJsonNode*(self: ProfileShowcaseVerifiedTokenPreference): JsonNode =
  %* {
    "symbol": self.symbol,
    "showcaseVisibility": self.showcaseVisibility.int,
    "order": self.order,
  }

proc toProfileShowcaseUnverifiedTokenPreference*(jsonObj: JsonNode): ProfileShowcaseUnverifiedTokenPreference =
  result = ProfileShowcaseUnverifiedTokenPreference()
  discard jsonObj.getProp("contractAddress", result.contractAddress)
  discard jsonObj.getProp("chainId", result.chainId)
  discard jsonObj.getProp("order", result.order)
  result.showcaseVisibility = jsonObj.toProfileShowcaseVisibility()

proc toJsonNode*(self: ProfileShowcaseUnverifiedTokenPreference): JsonNode =
  %* {
    "contractAddress": self.contractAddress,
    "chainId": self.chainId,
    "showcaseVisibility": self.showcaseVisibility.int,
    "order": self.order,
  }

proc toCombinedTokenId*(self: ProfileShowcaseUnverifiedTokenPreference): string =
  return fmt"{self.chainId}+{self.contractAddress}"

proc toProfileShowcaseSocialLinkPreference*(jsonObj: JsonNode): ProfileShowcaseSocialLinkPreference =
  result = ProfileShowcaseSocialLinkPreference()
  discard jsonObj.getProp("text", result.text)
  discard jsonObj.getProp("url", result.url)
  discard jsonObj.getProp("order", result.order)
  result.showcaseVisibility = jsonObj.toProfileShowcaseVisibility()

proc toJsonNode*(self: ProfileShowcaseSocialLinkPreference): JsonNode =
  %* {
    "text": self.text,
    "url": self.url,
    "showcaseVisibility": self.showcaseVisibility.int,
    "order": self.order,
  }

proc toProfileShowcasePreferencesDto*(jsonObj: JsonNode): ProfileShowcasePreferencesDto =
  result = ProfileShowcasePreferencesDto()

  if jsonObj["communities"].kind != JNull:
    for jsonMsg in jsonObj["communities"]:
      result.communities.add(jsonMsg.toProfileShowcaseCommunityPreference())
  if jsonObj["accounts"].kind != JNull:
    for jsonMsg in jsonObj["accounts"]:
      result.accounts.add(jsonMsg.toProfileShowcaseAccountPreference())
  if jsonObj["collectibles"].kind != JNull:
    for jsonMsg in jsonObj["collectibles"]:
      result.collectibles.add(jsonMsg.toProfileShowcaseCollectiblePreference())
  if jsonObj["verifiedTokens"].kind != JNull:
    for jsonMsg in jsonObj["verifiedTokens"]:
      result.verifiedTokens.add(jsonMsg.toProfileShowcaseVerifiedTokenPreference())
  if jsonObj["unverifiedTokens"].kind != JNull:
    for jsonMsg in jsonObj["unverifiedTokens"]:
      result.unverifiedTokens.add(jsonMsg.toProfileShowcaseUnverifiedTokenPreference())
  if jsonObj["socialLinks"].kind != JNull:
    for jsonMsg in jsonObj["socialLinks"]:
      result.socialLinks.add(jsonMsg.toProfileShowcaseSocialLinkPreference())

proc toJsonNode*(self: ProfileShowcasePreferencesDto): JsonNode =
  let communities = self.communities.map(entry => entry.toJsonNode())
  let accounts = self.accounts.map(entry => entry.toJsonNode())
  let collectibles = self.collectibles.map(entry => entry.toJsonNode())
  let verifiedTokens = self.verifiedTokens.map(entry => entry.toJsonNode())
  let unverifiedTokens = self.unverifiedTokens.map(entry => entry.toJsonNode())
  let socialLinks = self.socialLinks.map(entry => entry.toJsonNode())

  return %*[{
    "communities": communities,
    "accounts": accounts,
    "collectibles": collectibles,
    "verifiedTokens": verifiedTokens,
    "unverifiedTokens": unverifiedTokens,
    "socialLinks": socialLinks
  }]
