## Copy-on-Write Sequence Container
##
## Provides a seq-like container with transparent Copy-on-Write semantics.
## Memory is shared until a mutation occurs, at which point a copy is made.
##
## Key features:
## - Transparent CoW via =copy / =sink hooks
## - seq-compatible API
## - O(1) copy operations (refcount bump)
## - O(n) mutation only when shared
## - Atomic refcount: safe to copy/destroy across threads
## - Value type semantics (the wrapper itself can be copied freely)
##
## Example:
## ```nim
## var original = @[1, 2, 3].toCowSeq()
## var copy = original  # O(1) - shares memory
## copy.add(4)          # CoW triggered: copy gets its own buffer
## # original: [1, 2, 3]
## # copy: [1, 2, 3, 4]
## ```
##
## Threading model:
##   The refcount uses std/atomics so producer/consumer threads can copy and
##   destroy CowSeq values without races. NOTE: concurrent *mutation* of the
##   same CowSeq instance is still unsupported - the mutating thread must own
##   its instance. The supported pattern is: producer thread mutates its own
##   CowSeq, consumer threads each hold their own copy (same backing buffer
##   until any of them mutates).

import std/[hashes, atomics]

type
  CowSeqData[T] = ref object
    ## Internal data container with atomic reference counting.
    ## Not exported - callers should never reach in here.
    data: seq[T]
    refCount: Atomic[int]

  CowSeq*[T] = object
    ## Copy-on-Write sequence container.
    ## Behaves like seq[T] but shares the backing buffer until mutation.
    dataRef: CowSeqData[T]

#
# Constructors
#

proc newCowSeq*[T](initialData: seq[T] = @[]): CowSeq[T] =
  ## Create a new CowSeq from a regular seq.
  ## Takes the input by value so the caller's variable remains usable
  ## (important for code paths that emit signals/events containing the
  ## same data after constructing the CowSeq).
  result.dataRef = CowSeqData[T](data: initialData)
  result.dataRef.refCount.store(1)

proc newCowSeq*[T](size: int): CowSeq[T] =
  ## Create a new CowSeq with pre-allocated size.
  ## Time: O(n)
  result.dataRef = CowSeqData[T](data: newSeq[T](size))
  result.dataRef.refCount.store(1)

proc toCowSeq*[T](s: seq[T]): CowSeq[T] {.inline.} =
  ## Convert a regular seq to CowSeq (copy semantics - see newCowSeq).
  newCowSeq(s)

#
# Lifecycle hooks (transparent CoW)
#

proc `=destroy`*[T](x: var CowSeq[T]) =
  ## Destructor: atomically decrements the refcount and drops the ref.
  ## With --mm:refc, the GC reclaims `dataRef` once the last CowSeq holding
  ## it nils its slot.
  if not x.dataRef.isNil:
    discard x.dataRef.refCount.fetchSub(1, moAcquireRelease)
    x.dataRef = nil

proc `=copy`*[T](dest: var CowSeq[T], src: CowSeq[T]) =
  ## Copy hook: O(1) - shares the buffer and bumps the refcount.
  if dest.dataRef == src.dataRef:
    return  # Self-assignment

  # Release current ref (if any)
  `=destroy`(dest)
  wasMoved(dest)

  # Adopt the new ref
  if not src.dataRef.isNil:
    dest.dataRef = src.dataRef
    discard dest.dataRef.refCount.fetchAdd(1, moAcquireRelease)

proc `=sink`*[T](dest: var CowSeq[T], src: CowSeq[T]) =
  ## Sink hook: transfers ownership without touching the refcount.
  ## Critical: we must clear the source so its eventual destructor does not
  ## decrement the refcount we just transferred (B2 in the review).
  if dest.dataRef == src.dataRef:
    # Same buffer - clear source so its destructor is a no-op.
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
  if self.dataRef.isNil:
    self.dataRef = CowSeqData[T](data: @[])
    self.dataRef.refCount.store(1)
    return

  if self.dataRef.refCount.load(moAcquire) > 1:
    # Buffer is shared - fork it.
    let newData = self.dataRef.data  # Nim seq value semantics: deep copy
    discard self.dataRef.refCount.fetchSub(1, moAcquireRelease)
    self.dataRef = CowSeqData[T](data: newData)
    self.dataRef.refCount.store(1)

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
  ## seq[T]'s out-of-bounds behaviour. (B3)
  if self.dataRef.isNil:
    raise newException(IndexDefect, "CowSeq is empty (nil dataRef)")
  self.dataRef.data[idx]

proc `[]`*[T](self: CowSeq[T], slice: HSlice[int, int]): seq[T] =
  if self.dataRef.isNil:
    return @[]
  self.dataRef.data[slice]

proc borrow*[T](self: var CowSeq[T]): lent seq[T] {.inline.} =
  ## Zero-copy read access to the underlying seq. (H1)
  ## The returned reference is valid until `self` is mutated.
  ## Use this in hot paths instead of asSeq() to avoid the O(n) copy.
  ##
  ## Lazily initializes a default-constructed CowSeq with an empty buffer
  ## (hence the `var` self - we may need to allocate the empty backing).
  if self.dataRef.isNil:
    self.dataRef = CowSeqData[T](data: @[])
    self.dataRef.refCount.store(1)
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
    self.dataRef.data.add(other.dataRef.data)  # Bulk concat (M2)

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
  if self.dataRef.isNil:
    return
  if self.dataRef.refCount.load(moAcquire) > 1:
    discard self.dataRef.refCount.fetchSub(1, moAcquireRelease)
    self.dataRef = CowSeqData[T](data: @[])
    self.dataRef.refCount.store(1)
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
  ## For zero-copy reads, use `borrow()` instead. (H1)
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
    else: self.dataRef.refCount.load(moAcquire)

  proc isShared*[T](self: CowSeq[T]): bool =
    if self.dataRef.isNil: false
    else: self.dataRef.refCount.load(moAcquire) > 1
