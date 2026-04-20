## Tests for src/app/core/cow_seq.nim
##
## Coverage focus:
##   - Basic seq-compatible API (read, write, iterate)
##   - CoW semantics: copies share until mutation, then fork
##   - B2 fix: =sink correctly transfers ownership without double-decrement
##   - B3 fix: indexed access on a default-constructed CowSeq raises
##           IndexDefect (not SIGSEGV)
##   - H1 fix: borrow() returns a lent reference (no copy)
##
## Build with `-d:testing` so the debug helpers (getRefCount/isShared) are
## visible.

{.define: testing.}

import unittest, sequtils
import app/core/cow_seq

suite "CowSeq - basics":
  test "empty default-constructed CowSeq":
    var s: CowSeq[int]
    check s.len == 0
    check s.high == -1

  test "construct from seq":
    let s = toCowSeq(@[1, 2, 3])
    check s.len == 3
    check s[0] == 1
    check s[2] == 3

  test "iterate items":
    let s = toCowSeq(@[10, 20, 30])
    var collected: seq[int] = @[]
    for x in s:
      collected.add(x)
    check collected == @[10, 20, 30]

  test "iterate pairs":
    let s = toCowSeq(@["a", "b", "c"])
    var keys: seq[int] = @[]
    var vals: seq[string] = @[]
    for k, v in s:
      keys.add(k)
      vals.add(v)
    check keys == @[0, 1, 2]
    check vals == @["a", "b", "c"]

  test "add / delete / insert / setLen":
    var s = toCowSeq(@[1, 2, 3])
    s.add(4)
    check s.asSeq == @[1, 2, 3, 4]
    s.insert(0, 0)
    check s.asSeq == @[0, 1, 2, 3, 4]
    s.delete(2)
    check s.asSeq == @[0, 1, 3, 4]
    s.setLen(2)
    check s.asSeq == @[0, 1]

  test "equality":
    let a = toCowSeq(@[1, 2, 3])
    let b = toCowSeq(@[1, 2, 3])
    let c = toCowSeq(@[1, 2, 4])
    check a == b
    check a != c

suite "CowSeq - copy on write":
  test "copy is O(1) - shares backing buffer":
    var a = toCowSeq(@[1, 2, 3])
    var b = a
    check a.getRefCount == 2
    check b.getRefCount == 2
    check a.isShared
    check b.isShared

  test "mutation forks the buffer":
    var a = toCowSeq(@[1, 2, 3])
    var b = a
    check a.isShared

    b.add(4)
    # b should now be unique; a should be unique too (refCount drops to 1)
    check not b.isShared
    check not a.isShared
    check a.asSeq == @[1, 2, 3]
    check b.asSeq == @[1, 2, 3, 4]

  test "destructor releases the buffer":
    var a = toCowSeq(@[1, 2, 3])
    block:
      let b = a
      check a.getRefCount == 2
    # b is destroyed here
    check a.getRefCount == 1

  test "self-assignment is a no-op":
    var a = toCowSeq(@[1, 2, 3])
    a = a
    check a.getRefCount == 1
    check a.asSeq == @[1, 2, 3]

  test "B2: =sink does not double-decrement":
    # If =sink left src.dataRef intact, the moved-from variable's destructor
    # would decrement again -> the surviving copy's refcount would be wrong.
    proc returnsCow(): CowSeq[int] =
      var local = toCowSeq(@[1, 2, 3])
      result = local  # sink
    var s = returnsCow()
    check s.getRefCount == 1
    check s.asSeq == @[1, 2, 3]
    # If the sink was buggy, refcount would be 0 and s would be a dangling ref.

suite "CowSeq - safety fixes":
  test "B3: indexed access on default-constructed CowSeq raises":
    var s: CowSeq[int]
    expect IndexDefect:
      discard s[0]

  test "B3: slice access on default-constructed CowSeq returns empty":
    var s: CowSeq[int]
    check s[0..10] == newSeq[int]()

  test "H1: borrow returns lent view, mutates lazily-init the buffer":
    var s: CowSeq[int]
    let view = s.borrow()
    check view.len == 0
    # After borrow, the buffer exists.
    check s.getRefCount == 1

    var t = toCowSeq(@[1, 2, 3])
    let tview = t.borrow()
    check tview.len == 3
    check tview[0] == 1

  test "clear releases shared buffer in O(1)":
    var a = toCowSeq(@[1, 2, 3])
    var b = a
    check a.isShared
    a.clear()
    check a.len == 0
    check not a.isShared
    check b.asSeq == @[1, 2, 3]   # b is unaffected

suite "CowSeq - bulk add":
  test "add seq concatenation (M2)":
    var a = toCowSeq(@[1, 2])
    a.add(@[3, 4, 5])
    check a.asSeq == @[1, 2, 3, 4, 5]

  test "add CowSeq concatenation":
    var a = toCowSeq(@[1, 2])
    let b = toCowSeq(@[3, 4])
    a.add(b)
    check a.asSeq == @[1, 2, 3, 4]
