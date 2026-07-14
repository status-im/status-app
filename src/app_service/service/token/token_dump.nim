## Deterministic token-model dump serializer.
##
## Serializes the token service's externally observable state into a sorted,
## diff-friendly text snapshot. Two dumps of identical state are byte-identical:
## every collection is emitted in sorted-key order and there are no timestamps or
## other run-varying fields. Pure (data in, string out) so it can be unit-tested
## and used to compare token-service state across a code change (pre/post a fix).

import algorithm, sequtils, sets, strutils, tables
import std/os
import seaqt/qstandardpaths

import items/token
import items/token_group
import items/preferences

proc sortedKeys[T](t: Table[string, T]): seq[string] =
  result = toSeq(t.keys)
  result.sort()

proc section(result: var string, name: string, count: int) =
  result.add("## " & name & " (" & $count & ")\n")

proc joinSortedTokenKeys(tokens: seq[TokenItem]): string =
  var keys = tokens.mapIt(it.key)
  keys.sort()
  keys.join(",")

proc dumpTokenState*(
    tokensOfInterest: Table[string, TokenItem],
    groupsOfInterest: Table[string, TokenGroupItem],
    allTokensByGroupKey: Table[string, seq[TokenItem]],
    preferences: Table[string, TokenPreferencesItem],
    knownMissingKeys: HashSet[string],
    pendingKeys: seq[string],
    inFlightKeys: seq[string]): string =
  ## Build the deterministic dump. Sections are emitted in a fixed order; within
  ## each section, rows are sorted by their leading key.

  result.section("tokensOfInterest", tokensOfInterest.len)
  for key in tokensOfInterest.sortedKeys:
    let t = tokensOfInterest[key]
    result.add(@[key, t.symbol, t.name, $t.chainId, $t.decimals, t.address,
      t.groupKey, $t.`type`].join("\t") & "\n")

  result.section("groupsOfInterest", groupsOfInterest.len)
  for key in groupsOfInterest.sortedKeys:
    let g = groupsOfInterest[key]
    result.add(@[key, g.name, g.symbol, $g.decimals,
      joinSortedTokenKeys(g.tokens)].join("\t") & "\n")

  result.section("allTokensByGroupKey", allTokensByGroupKey.len)
  for key in allTokensByGroupKey.sortedKeys:
    result.add(key & "\t" & joinSortedTokenKeys(allTokensByGroupKey[key]) & "\n")

  result.section("preferences", preferences.len)
  for key in preferences.sortedKeys:
    let p = preferences[key]
    result.add(@[key, $p.position, $p.groupPosition, $p.visible,
      p.communityId].join("\t") & "\n")

  result.section("knownMissingKeys", knownMissingKeys.len)
  for key in sorted(toSeq(knownMissingKeys.items)):
    result.add(key & "\n")

  result.section("pendingFetch.pending", pendingKeys.len)
  for key in sorted(pendingKeys):
    result.add(key & "\n")

  result.section("pendingFetch.inFlight", inFlightKeys.len)
  for key in sorted(inFlightKeys):
    result.add(key & "\n")

const TOKEN_DUMP_FILENAME* = "token-dump.txt"

proc writeTokenDump*(content: string): string =
  ## Write the dump to the app data dir (external files dir on Android, so it is
  ## reachable by adb) and return the absolute path. Raises on IO failure — the
  ## caller logs it. Kept out of the QtObject service module so its seaqt import
  ## does not collide with nimqml's QMetaObject.
  let dir = QStandardPaths.writableLocation(
    cint(QStandardPathsStandardLocationEnum.AppDataLocation))
  createDir(dir)
  result = dir / TOKEN_DUMP_FILENAME
  writeFile(result, content)
