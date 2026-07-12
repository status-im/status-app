## Copy-on-Write Sequence Container (single-threaded)
##
## A seq-like container with transparent Copy-on-Write semantics: memory is
## shared between copies until a mutation occurs, at which point the mutating
## copy forks its own buffer.
##
## Key features:
## - Transparent CoW via =copy / =sink hooks
## - seq-compatible API
## - O(1) copy operations (refcount bump)
## - O(n) mutation only when the buffer is shared
## - Value type semantics (the wrapper itself can be copied freely)
##
## Refcount type: a PLAIN `int`, not an atomic. The intended flow keeps every
## CowSeq on the GUI thread — the service owns the authoritative CowSeq and the
## GUI-thread model diffs prev vs next against it; worker state reaches the GUI
## thread via a typed move (typed_handoff), so a CowSeq value never crosses a
## thread boundary. Under single-thread use there is no contention, so an atomic
## refcount would only add cost. Do NOT copy/destroy a CowSeq from another thread.
##
## Example:
## ```nim
## var original = @[1, 2, 3].toCowSeq()
## var copy = original  # O(1) - shares memory
## copy.add(4)          # CoW triggered: copy gets its own buffer
## # original: [1, 2, 3]
## # copy: [1, 2, 3, 4]
## ```

import std/hashes

type
  CowSeqData[T] = ref object
    ## Internal data container with reference counting.
    ## Not exported - callers should never reach in here.
    data: seq[T]
    refCount: int
    owningThread: int  ## thread that created the buffer; mutations must stay on it

  CowSeq*[T] = object
    ## Copy-on-Write sequence container.
    ## Behaves like seq[T] but shares the backing buffer until mutation.
    dataRef: CowSeqData[T]

#
# Thread-ownership guard (debug-only)
#

proc cowOwningThreadId(): int {.inline.} =
  ## Current thread id under a threaded build, else 0 (single-thread build).
  when compileOption("threads"):
    getThreadId()
  else:
    0

proc assertOwningThread[T](self: CowSeq[T]) {.inline.} =
  ## Enforce the documented single-thread (GUI-thread) mutation constraint.
  when compileOption("assertions"):
    if not self.dataRef.isNil:
      assert self.dataRef.owningThread == cowOwningThreadId(),
        "CowSeq mutated from a thread other than the one that created it"

#
# Constructors
#

proc newCowSeq*[T](initialData: seq[T] = @[]): CowSeq[T] =
  ## Create a new CowSeq from a regular seq.
  ## Takes the input by value so the caller's variable remains usable.
  result.dataRef = CowSeqData[T](data: initialData, refCount: 1,
    owningThread: cowOwningThreadId())

proc newCowSeq*[T](size: int): CowSeq[T] =
  ## Create a new CowSeq with pre-allocated size.
  result.dataRef = CowSeqData[T](data: newSeq[T](size), refCount: 1,
    owningThread: cowOwningThreadId())

proc toCowSeq*[T](s: seq[T]): CowSeq[T] {.inline.} =
  ## Convert a regular seq to CowSeq (copy semantics - see newCowSeq).
  newCowSeq(s)

#
# Lifecycle hooks (transparent CoW)
#

proc `=destroy`*[T](x: var CowSeq[T]) =
  ## Destructor: decrements the refcount and drops the ref.
  if not x.dataRef.isNil:
    dec x.dataRef.refCount
    x.dataRef = nil

proc `=copy`*[T](dest: var CowSeq[T], src: CowSeq[T]) =
  ## Copy hook: O(1) - shares the buffer and bumps the refcount.
  if dest.dataRef == src.dataRef:
    return  # Self-assignment

  `=destroy`(dest)
  wasMoved(dest)

  if not src.dataRef.isNil:
    dest.dataRef = src.dataRef
    inc dest.dataRef.refCount

proc `=sink`*[T](dest: var CowSeq[T], src: CowSeq[T]) =
  ## Sink hook: transfers ownership without touching the refcount.
  ## Clears the source so its eventual destructor does not decrement the
  ## refcount we just transferred.
  # Self-move (`a = move(a)`): leave dest intact, never clear it.
  if cast[pointer](unsafeAddr dest) == cast[pointer](unsafeAddr src):
    return

  if dest.dataRef == src.dataRef:
    # dest and src alias the same buffer: release src's reference so dest keeps
    # exactly one and the refcount stays balanced (else it leaks one).
    if not src.dataRef.isNil:
      dec src.dataRef.refCount
    cast[ptr CowSeq[T]](unsafeAddr src).dataRef = nil
    return

  `=destroy`(dest)
  wasMoved(dest)
  dest.dataRef = src.dataRef
  cast[ptr CowSeq[T]](unsafeAddr src).dataRef = nil

#
# Internal: CoW trigger
#

proc ensureUnique[T](self: var CowSeq[T]) =
  ## Ensure this CowSeq has exclusive ownership of its data.
  ## Triggers Copy-on-Write if the buffer is shared.
  self.assertOwningThread()
  if self.dataRef.isNil:
    self.dataRef = CowSeqData[T](data: @[], refCount: 1,
      owningThread: cowOwningThreadId())
    return

  if self.dataRef.refCount > 1:
    let newData = self.dataRef.data  # Nim seq value semantics: deep copy
    dec self.dataRef.refCount
    self.dataRef = CowSeqData[T](data: newData, refCount: 1,
      owningThread: cowOwningThreadId())

#
# Read-only operations (O(1), no CoW)
#

proc len*[T](self: CowSeq[T]): int {.inline.} =
  if self.dataRef.isNil: 0
  else: self.dataRef.data.len

proc high*[T](self: CowSeq[T]): int {.inline.} =
  self.len - 1

proc low*[T](self: CowSeq[T]): int {.inline.} =
  0

proc `[]`*[T](self: CowSeq[T], idx: int): lent T {.inline.} =
  ## Access element at index (read-only).
  ## Raises IndexDefect on a default-constructed (nil) CowSeq, mirroring
  ## seq[T]'s out-of-bounds behaviour.
  if self.dataRef.isNil:
    raise newException(IndexDefect, "CowSeq is empty (nil dataRef)")
  self.dataRef.data[idx]

proc `[]`*[T](self: CowSeq[T], slice: HSlice[int, int]): seq[T] =
  if self.dataRef.isNil:
    return @[]
  self.dataRef.data[slice]

proc borrow*[T](self: var CowSeq[T]): lent seq[T] {.inline.} =
  ## Zero-copy read access to the underlying seq.
  ## The returned reference is valid until `self` is mutated.
  ## Use this in hot paths instead of asSeq() to avoid the O(n) copy.
  if self.dataRef.isNil:
    self.dataRef = CowSeqData[T](data: @[], refCount: 1,
      owningThread: cowOwningThreadId())
  result = self.dataRef.data

#
# Mutable operations (trigger CoW if shared)
#

proc `[]=`*[T](self: var CowSeq[T], idx: int, val: T) =
  self.ensureUnique()
  self.dataRef.data[idx] = val

proc add*[T](self: var CowSeq[T], val: sink T) =
  self.ensureUnique()
  self.dataRef.data.add(val)

proc add*[T](self: var CowSeq[T], other: CowSeq[T]) =
  if other.len == 0:
    return
  self.ensureUnique()
  if not other.dataRef.isNil:
    self.dataRef.data.add(other.dataRef.data)

proc add*[T](self: var CowSeq[T], other: openArray[T]) =
  if other.len == 0:
    return
  self.ensureUnique()
  for item in other:
    self.dataRef.data.add(item)

proc delete*[T](self: var CowSeq[T], idx: int) =
  self.ensureUnique()
  self.dataRef.data.delete(idx)

proc delete*[T](self: var CowSeq[T], first: int, last: int) =
  self.ensureUnique()
  for i in countdown(last, first):
    self.dataRef.data.delete(i)

proc insert*[T](self: var CowSeq[T], val: sink T, idx: int = 0) =
  self.ensureUnique()
  self.dataRef.data.insert(val, idx)

proc setLen*[T](self: var CowSeq[T], newLen: int) =
  self.ensureUnique()
  self.dataRef.data.setLen(newLen)

proc clear*[T](self: var CowSeq[T]) =
  ## Empty the sequence (O(1) when shared - drops the buffer; O(n) when unique).
  self.assertOwningThread()
  if self.dataRef.isNil:
    return
  if self.dataRef.refCount > 1:
    dec self.dataRef.refCount
    self.dataRef = CowSeqData[T](data: @[], refCount: 1,
      owningThread: cowOwningThreadId())
  else:
    self.dataRef.data.setLen(0)

#
# Iteration
#

iterator items*[T](self: CowSeq[T]): lent T =
  if not self.dataRef.isNil:
    for item in self.dataRef.data:
      yield item

iterator mitems*[T](self: var CowSeq[T]): var T =
  ## Mutable iteration. Always triggers CoW if shared - even if the caller
  ## doesn't end up writing. Prefer `items` for read-only loops.
  self.ensureUnique()
  for item in self.dataRef.data.mitems:
    yield item

iterator pairs*[T](self: CowSeq[T]): tuple[key: int, val: lent T] =
  if not self.dataRef.isNil:
    for i, item in self.dataRef.data.pairs:
      yield (i, item)

#
# Conversion
#

proc asSeq*[T](self: CowSeq[T]): seq[T] =
  ## Returns a *copy* of the underlying seq. Always O(n).
  ## For zero-copy reads, use `borrow()` instead.
  if self.dataRef.isNil: @[]
  else: self.dataRef.data

#
# Comparison
#

proc `==`*[T](a, b: CowSeq[T]): bool =
  if a.dataRef == b.dataRef:
    return true  # Same backing buffer
  if a.len != b.len:
    return false
  for i in 0..<a.len:
    if a[i] != b[i]:
      return false
  return true

proc hash*[T](self: CowSeq[T]): Hash =
  var h: Hash = 0
  for item in self:
    h = h !& hash(item)
  result = !$h

#
# Utility
#

proc contains*[T](self: CowSeq[T], val: T): bool =
  if self.dataRef.isNil:
    return false
  for item in self.dataRef.data:
    if item == val:
      return true
  return false

proc find*[T](self: CowSeq[T], val: T): int =
  if self.dataRef.isNil:
    return -1
  for i, item in self.dataRef.data:
    if item == val:
      return i
  return -1

proc `$`*[T](self: CowSeq[T]): string =
  if self.dataRef.isNil:
    return "@[]"
  result = "@["
  for i, item in self:
    if i > 0:
      result.add(", ")
    result.add($item)
  result.add("]")

#
# Debug helpers (test-only - guarded so production callers cannot branch on them)
#

when defined(testing) or defined(QT_MODEL_SPY):
  proc getRefCount*[T](self: CowSeq[T]): int =
    if self.dataRef.isNil: 0
    else: self.dataRef.refCount

  proc isShared*[T](self: CowSeq[T]): bool =
    if self.dataRef.isNil: false
    else: self.dataRef.refCount > 1
