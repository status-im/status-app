## The dense model's QML contract, checked mechanically.
##
## The QML dense-window work (issues 0022/0023) is driven by a ListModel STUB
## in `tst_DenseWindow.qml`. Nothing has ever run the QML against the real
## `DenseModel`, so the two agree only because someone read both files. This
## test is the check that goes red when they drift: it extracts the contract
## from the Nim sources and from the QML that consumes it, and compares them.
##
## Three seams are covered:
##
## 1. **Role names** — every role the stub presents must exist on the real
##    model, and every role the production view *renames* (and therefore
##    reads) must exist on both. A rename against a role the model does not
##    have is a silent no-op that leaves the delegate unbound.
## 2. **The view's QML-facing API** — the slots and the signal the dense path
##    calls must exist on `View` with the arity the stub declares.
## 3. **The dummy key prefix** — the QML anchoring rules hinge on a dummy key
##    being recognisable; the constant lives in Nim and is asserted here.
##
## Pure text extraction on purpose: it needs no Qt and therefore runs.

import std/[os, sets, strutils, tables]
import unittest

const repoRoot = currentSourcePath().parentDir.parentDir.parentDir

const
  denseModelPath = repoRoot / "src/app/modules/shared_models/dense_message_model.nim"
  viewPath = repoRoot / "src/app/modules/main/chat_section/chat_content/messages/view.nim"
  modulePath = repoRoot / "src/app/modules/main/chat_section/chat_content/messages/module.nim"
  chatViewPath = repoRoot / "ui/app/AppLayouts/Chat/views/ChatMessagesView.qml"
  storePath = repoRoot / "ui/app/AppLayouts/Chat/stores/MessageStore.qml"
  stubPath = repoRoot / "storybook/qmlTests/tests/tst_DenseWindow.qml"
  stubStorePath = repoRoot / "storybook/stubs/AppLayouts/Chat/stores/MessageStore.qml"

proc readSource(path: string): string =
  require(fileExists(path))
  readFile(path)

## Blanks out string literals so brace counting and `:` splitting cannot be
## confused by punctuation inside them.
proc stripStrings(line: string): string =
  result = newStringOfCap(line.len)
  var inStr = false
  var i = 0
  while i < line.len:
    let c = line[i]
    if c == '\\' and inStr:
      i += 2
      continue
    if c == '"':
      inStr = not inStr
      result.add ' '
      i += 1
      continue
    result.add(if inStr: ' ' else: c)
    i += 1

proc firstQuoted(line: string): string =
  let a = line.find('"')
  if a < 0:
    return ""
  let b = line.find('"', a + 1)
  if b < 0:
    return ""
  line[a + 1 ..< b]

# ---------------------------------------------------------------- Nim model

## The role names `DenseModel.roleNames` publishes.
proc modelRoleNames(src: string): HashSet[string] =
  result = initHashSet[string]()
  var inBody = false
  for line in src.splitLines:
    if line.contains("method roleNames(self: DenseModel)"):
      inBody = true
      continue
    if not inBody:
      continue
    if line.contains(".toTable"):
      break
    if line.contains("ModelRole.") and line.contains(".int:"):
      let name = firstQuoted(line)
      if name.len > 0:
        result.incl name

## `proc <name>*(self: View, ...) {.slot.}` / `{.signal.}` -> parameter names.
proc viewMembers(src: string, pragma: string): Table[string, seq[string]] =
  result = initTable[string, seq[string]]()
  for raw in src.splitLines:
    let line = raw.strip
    if not line.startsWith("proc ") or not line.contains("{." & pragma & ".}"):
      continue
    let open = line.find('(')
    let close = line.rfind(')')
    if open < 0 or close < open:
      continue
    var name = line[5 ..< open].strip
    name.removeSuffix("*")
    var params: seq[string] = @[]
    for part in line[open + 1 ..< close].split(','):
      let p = part.strip
      if p.len == 0 or p.startsWith("self:"):
        continue
      params.add p.split(':')[0].strip
    result[name] = params

# ---------------------------------------------------------------- QML side

## The object literal keys the stub's `loadedRoles()` builds a row from.
proc stubRoleNames(src: string): HashSet[string] =
  result = initHashSet[string]()
  var depth = 0
  var started = false
  for raw in src.splitLines:
    let line = stripStrings(raw)
    if not started:
      if not line.contains("function loadedRoles("):
        continue
      started = true
    if started and depth > 0:
      let body = line.strip
      let colon = body.find(':')
      if colon > 0:
        let key = body[0 ..< colon].strip
        if key.len > 0 and (key[0].isAlphaAscii or key[0] == '_') and
            key.allCharsInSet({'a'..'z', 'A'..'Z', '0'..'9', '_'}):
          result.incl key
    depth += line.count('{') - line.count('}')
    if started and depth <= 0:
      break

## The source roles the production view renames for the delegate. A rename of
## a role the model does not publish silently binds nothing.
proc renamedSourceRoles(src: string): HashSet[string] =
  result = initHashSet[string]()
  for line in src.splitLines:
    if line.contains("RoleRename") and line.contains("from:"):
      let name = firstQuoted(line[line.find("from:") ..< line.len])
      if name.len > 0:
        result.incl name

## `function foo(a, b)` / `signal foo(int a, string b)` -> parameter names.
proc qmlMembers(src: string, keyword: string): Table[string, seq[string]] =
  result = initTable[string, seq[string]]()
  for raw in src.splitLines:
    let line = raw.strip
    if not line.startsWith(keyword & " "):
      continue
    let open = line.find('(')
    let close = line.find(')', open + 1)
    if open < 0 or close < open:
      continue
    let name = line[keyword.len + 1 ..< open].strip
    var params: seq[string] = @[]
    for part in line[open + 1 ..< close].split(','):
      let p = part.strip
      if p.len == 0:
        continue
      # a signal declares `<type> <name>`, a function just `<name>`
      let words = p.splitWhitespace
      params.add words[^1]
    result[name] = params

let
  denseModelSrc = readSource(denseModelPath)
  viewSrc = readSource(viewPath)
  moduleSrc = readSource(modulePath)
  chatViewSrc = readSource(chatViewPath)
  storeSrc = readSource(storePath)
  stubSrc = readSource(stubPath)
  stubStoreSrc = readSource(stubStorePath)

  modelRoles = modelRoleNames(denseModelSrc)
  stubRoles = stubRoleNames(stubSrc)
  viewSlots = viewMembers(viewSrc, "slot")
  viewSignals = viewMembers(viewSrc, "signal")

suite "dense model roles":
  test "the extraction found a plausible role set":
    # guards the parser itself: a regex that silently matches nothing would
    # make every subset check below pass vacuously
    check(modelRoles.len > 50)
    check(stubRoles.len > 40)
    check("key" in modelRoles)
    check("loaded" in modelRoles)
    check("messageText" in modelRoles)

  test "every role the QML stub presents exists on the real model":
    var missing: seq[string] = @[]
    for role in stubRoles:
      if role notin modelRoles:
        missing.add role
    check(missing.len == 0)
    if missing.len > 0:
      echo "stub roles absent from DenseModel.roleNames: ", missing

  test "every role the production view renames exists on both":
    let renamed = renamedSourceRoles(chatViewSrc)
    check(renamed.len > 20)
    var missingOnModel: seq[string] = @[]
    var missingOnStub: seq[string] = @[]
    for role in renamed:
      if role notin modelRoles:
        missingOnModel.add role
      if role notin stubRoles:
        missingOnStub.add role
    check(missingOnModel.len == 0)
    check(missingOnStub.len == 0)
    if missingOnModel.len > 0:
      echo "renamed roles absent from DenseModel: ", missingOnModel
    if missingOnStub.len > 0:
      echo "renamed roles absent from the stub: ", missingOnStub

  test "the roles the dense delegate reads unrenamed exist on both":
    # read straight off `model.` in the shell delegate and the window
    # bookkeeping, so they never pass through the rename mapping
    for role in ["key", "loaded", "deleted"]:
      check(role in modelRoles)
      check(role in stubRoles)

  test "a dummy key is prefixed and therefore recognisable":
    check(denseModelSrc.contains("DUMMY_KEY_PREFIX* = \"dummy:\""))
    # the model must answer `key` with the message id for a loaded row: that
    # is what lets goTo pin a teleport on a stable id
    check(denseModelSrc.contains("return newQVariant(self.store.rowAt(row).id)"))

suite "the view's QML-facing dense API":
  test "the slots the store calls exist on the view":
    const expected = {
      "loadMessagesAroundMessage": @["messageId"],
      "loadMessagesAtRank": @["rank"],
      "setDenseWindow": @["firstIndex", "lastIndex", "margin"],
      "indexOfMessageId": @["messageId"],
      "jumpToMessage": @["messageId"],
    }.toTable
    for name, params in expected:
      check(name in viewSlots)
      if name in viewSlots:
        check(viewSlots[name].len == params.len)

  test "the window-loaded signal carries the anchor id, index and error":
    check("messagesWindowLoaded" in viewSignals)
    check(viewSignals.getOrDefault("messagesWindowLoaded") ==
          @["anchorId", "anchorIndex", "error"])

  test "the id-based jump signal exists and is what the dense path emits":
    check("scrollToMessageId" in viewSignals)
    check(viewSignals.getOrDefault("scrollToMessageId") == @["messageId"])
    check(moduleSrc.contains("emitScrollToMessageIdSignal"))

  test "the dense branch returns before the legacy page hunt":
    # `checkIfMessageLoadedAndScroll` walks the legacy model and pages until
    # the message shows up. The dense model knows every message's position,
    # so the dense branch must leave scrollToMessage before any of that
    # bookkeeping starts.
    let start = moduleSrc.find("method scrollToMessage*(self: Module")
    check(start >= 0)
    let body = moduleSrc[start ..< moduleSrc.len]
    let denseBranch = body.find("emitScrollToMessageIdSignal")
    let hunt = body.find("setSearchedMessageId")
    check(denseBranch >= 0)
    check(hunt >= 0)
    check(denseBranch < hunt)
    # ordering alone would still pass with the branch falling through: the
    # emit has to be the last thing the dense path does
    check(body.contains("self.view.emitScrollToMessageIdSignal(messageId)\n    return\n"))
    # and the hunt itself must still be reached only through that method
    check(moduleSrc.count("increaseLoadingMessagesPerPageFactor") == 1)

  test "the stub declares the same API the view exposes":
    let stubFns = qmlMembers(stubSrc, "function")
    let stubSignals = qmlMembers(stubSrc, "signal")
    for name in ["loadMessagesAroundMessage", "loadMessagesAtRank",
                 "setDenseWindow", "indexOfMessageId"]:
      check(name in stubFns)
      if name in stubFns and name in viewSlots:
        check(stubFns[name].len == viewSlots[name].len)
    check("messagesWindowLoaded" in stubSignals)
    check(stubSignals.getOrDefault("messagesWindowLoaded").len ==
          viewSignals.getOrDefault("messagesWindowLoaded").len)
    check("scrollToMessageId" in stubSignals)

  test "both message stores wrap the same dense surface":
    for name in ["loadMessagesAroundMessage", "loadMessagesAtRank",
                 "setDenseWindow", "indexOfMessage", "jumpToMessage"]:
      check(storeSrc.contains("function " & name & "("))
      check(stubStoreSrc.contains("function " & name & "("))

suite "every jump reaches the primitive":
  test "no QML calls the message module's jump behind the store":
    # goTo is one primitive: the store's jumpToMessage. A call straight to
    # messageModule bypasses it - and the store layer with it.
    var offenders: seq[string] = @[]
    for path in walkDirRec(repoRoot / "ui"):
      if not path.endsWith(".qml"):
        continue
      let src = readFile(path)
      if src.contains("messageModule.jumpToMessage") and
          not path.endsWith("stores/MessageStore.qml"):
        offenders.add path.relativePath(repoRoot)
      if src.contains("messageModule.scrollToMessage("):
        offenders.add path.relativePath(repoRoot)
    check(offenders.len == 0)
    if offenders.len > 0:
      echo "QML reaching past the store's jump primitive: ", offenders
