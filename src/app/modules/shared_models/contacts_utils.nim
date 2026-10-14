import std/unicode

proc resolvePreferredDisplayName*(localNickName: string, ensName: string, displayName: string, alias: string): string =
    if localNickname != "":
      return localNickname
    if ensName != "":
      return ensName
    if displayName != "":
      return displayName
    if alias != "":
      return alias
    # This makes sure that people with no name are sorted last
    # This fake name is never shown to the user
    return "zzz"

proc resolveUsesDefaultName*(localNickName: string, ensName: string, displayName: string): bool =
  return displayName == "" and localNickname == "" and ensName == ""

# Rune-wise simple-casefold compare — the name leg of the canonical member
# order. Deliberately code-point based, not locale-collation aware.
proc cmpFoldedNames*(a, b: string): int =
  var i = 0
  var j = 0
  while i < a.len and j < b.len:
    var ra, rb: Rune
    fastRuneAt(a, i, ra)
    fastRuneAt(b, j, rb)
    let fa = toLower(ra)
    let fb = toLower(rb)
    if fa != fb:
      return cmp(fa.int32, fb.int32)
  cmp(a.len - i, b.len - j)
