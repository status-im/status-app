## Memoization for the pure per-public-key derivations exposed by `Utils`
## (color id, emoji hash). A miss costs up to three status-go FFI round-trips
## while the result never changes for a given key, and the UI asks for them
## once per message row it dresses.

import std/[options, tables]

type PubkeyMemo*[T] = ref object
  entries: Table[string, T]

proc newPubkeyMemo*[T](): PubkeyMemo[T] =
  PubkeyMemo[T](entries: initTable[string, T]())

## Returns the memoized value for `publicKey`, calling `compute` only on a miss.
proc get*[T](self: PubkeyMemo[T], publicKey: string,
             compute: proc(publicKey: string): T): T =
  self.entries.withValue(publicKey, hit):
    return hit[]
  result = compute(publicKey)
  self.entries[publicKey] = result

proc peek*[T](self: PubkeyMemo[T], publicKey: string): Option[T] =
  self.entries.withValue(publicKey, hit):
    return some(hit[])
  return none(T)

proc len*[T](self: PubkeyMemo[T]): int =
  self.entries.len

proc clear*[T](self: PubkeyMemo[T]) =
  self.entries.clear()
