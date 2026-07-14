## Unit tests for the pure token-model dump serializer.
## The dump is a deterministic, sorted, diff-friendly snapshot of the token
## service's observable state; two dumps of identical state must be byte-identical
## (stable ordering, no timestamps). No Qt/backend — pure data in, string out.

import unittest, tables, sets

import app_service/service/token/token_dump
import app_service/service/token/items/token
import app_service/service/token/items/token_group
import app_service/service/token/items/preferences
import app_service/service/token/dto/token as token_dto

proc testToken(chainId: int, address, symbol, name: string, decimals: int, group = ""): TokenItem =
  var dto: token_dto.TokenDto
  dto.chainId = chainId
  dto.address = address
  dto.symbol = symbol
  dto.name = name
  dto.decimals = decimals
  dto.crossChainId = group
  return createTokenItem(dto)

let tokenA = testToken(1, "0xaaa", "TKA", "Token A", 18, "grp1")
let tokenB = testToken(10, "0xbbb", "TKB", "Token B", 6, "grp1")

proc sampleGroups(): Table[string, TokenGroupItem] =
  result = initTable[string, TokenGroupItem]()
  result["grp1"] = TokenGroupItem(
    key: "grp1", name: "Group One", symbol: "GRP", decimals: 1, tokens: @[tokenA, tokenB])

proc samplePrefs(): Table[string, TokenPreferencesItem] =
  result = initTable[string, TokenPreferencesItem]()
  result["grp1"] = TokenPreferencesItem(
    key: "grp1", position: 0, groupPosition: 1, visible: true, communityId: "")

const expectedPopulated =
  "## tokensOfInterest (2)\n" &
  "1-0xaaa\tTKA\tToken A\t1\t18\t0xaaa\tgrp1\tERC20\n" &
  "10-0xbbb\tTKB\tToken B\t10\t6\t0xbbb\tgrp1\tERC20\n" &
  "## groupsOfInterest (1)\n" &
  "grp1\tGroup One\tGRP\t1\t1-0xaaa,10-0xbbb\n" &
  "## allTokensByGroupKey (1)\n" &
  "grp1\t1-0xaaa,10-0xbbb\n" &
  "## preferences (1)\n" &
  "grp1\t0\t1\ttrue\t\n" &
  "## knownMissingKeys (1)\n" &
  "1-0xdead\n" &
  "## pendingFetch.pending (1)\n" &
  "1-0xbeef\n" &
  "## pendingFetch.inFlight (0)\n"

suite "token model dump serializer":
  test "serializes a populated state exactly, sorted and sectioned":
    var byKey = initTable[string, TokenItem]()
    byKey["10-0xbbb"] = tokenB
    byKey["1-0xaaa"] = tokenA  # inserted out of order on purpose
    var allByGroup = initTable[string, seq[TokenItem]]()
    allByGroup["grp1"] = @[tokenB, tokenA]
    let dump = dumpTokenState(
      tokensOfInterest = byKey,
      groupsOfInterest = sampleGroups(),
      allTokensByGroupKey = allByGroup,
      preferences = samplePrefs(),
      knownMissingKeys = ["1-0xdead"].toHashSet,
      pendingKeys = @["1-0xbeef"],
      inFlightKeys = @[])
    check dump == expectedPopulated

  test "is byte-identical regardless of table insertion order":
    var a = initTable[string, TokenItem]()
    a["1-0xaaa"] = tokenA
    a["10-0xbbb"] = tokenB
    var b = initTable[string, TokenItem]()
    b["10-0xbbb"] = tokenB
    b["1-0xaaa"] = tokenA
    let dumpA = dumpTokenState(a, sampleGroups(), initTable[string, seq[TokenItem]](),
      samplePrefs(), ["z-0x1", "a-0x2"].toHashSet, @["m-0x3", "b-0x4"], @[])
    let dumpB = dumpTokenState(b, sampleGroups(), initTable[string, seq[TokenItem]](),
      samplePrefs(), ["a-0x2", "z-0x1"].toHashSet, @["b-0x4", "m-0x3"], @[])
    check dumpA == dumpB

  test "empty state yields zero-count sections":
    let dump = dumpTokenState(
      initTable[string, TokenItem](), initTable[string, TokenGroupItem](),
      initTable[string, seq[TokenItem]](), initTable[string, TokenPreferencesItem](),
      initHashSet[string](), @[], @[])
    check dump ==
      "## tokensOfInterest (0)\n" &
      "## groupsOfInterest (0)\n" &
      "## allTokensByGroupKey (0)\n" &
      "## preferences (0)\n" &
      "## knownMissingKeys (0)\n" &
      "## pendingFetch.pending (0)\n" &
      "## pendingFetch.inFlight (0)\n"
