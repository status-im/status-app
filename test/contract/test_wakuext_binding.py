"""Static guard on the wakuext FFI seam.

The app sends `{"method": "wakuext_<name>"}` to status-go, which resolves the
method by name at runtime. Renaming or removing a `wakuext` method there breaks
every app call site that names it — no compile error, no test unless one hits
that exact call.

Three static forms name a wakuext method in the app:
  1. a `"wakuext_<name>"` string literal (any scanned language),
  2. `"<name>".prefix` in Nim — `prefix` prepends a namespace; which namespace
     depends on the file (src/app_service/common/utils.nim exports the
     `wakuext_` one; three backend files define their own non-wakuext prefix),
  3. `rpc(<name>, "wakuext")` — the src/backend/gen.nim macro composes the
     method string at compile time.

Every name from all three forms must resolve to a method the vendored
status-go (the shipped pin) registers under the `wakuext` namespace.
Name-existence only: a method that exists but changed its params is out of
scope — the registered set is a superset of the truly-callable one.

Coverage is guarded from both ends: extracted names must resolve, and every
occurrence of a private-RPC entry point must yield an argument the parser can
classify — an unreadable one counts as unresolved and must be pinned in
_UNRESOLVED_ALLOWLIST, so within the scanned suffixes and entry points a new
composition idiom turns the gate red instead of shrinking coverage silently.
"""
from __future__ import annotations

import os
import re
from functools import lru_cache
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve()
APP_ROOT = _HERE.parents[2]
STATUS_GO_ROOT = APP_ROOT / "vendor" / "status-go"

# wakuv2ext serves the `wakuext` namespace and embeds ext's PublicAPI, so the
# registered set is the union of both files. test_wakuext_namespace_wiring
# asserts the embed and the namespace, so a status-go refactor that breaks
# either fails here instead of silently invalidating the union.
_GO_API_RELPATHS = ("services/ext/api.go", "services/wakuv2ext/api.go")

# Scan the whole tree so a call site in a new location (e.g. mobile/ios) can't
# silently drop out; over-scanning only risks a false FAIL.
_APP_SRC_SUFFIXES = {".nim", ".java", ".kt", ".swift", ".m", ".mm", ".qml",
                     ".js", ".jsx", ".mjs", ".ts", ".tsx", ".cpp", ".cc",
                     ".h", ".hpp"}
_SCAN_SKIP_DIRS = {"vendor", ".git", "build", "node_modules", "result", ".cache"}

_GO_METHOD_RE = re.compile(r"^func \(\w+ \*PublicAPI\) ([A-Z][A-Za-z0-9]*)\(", re.M)
_LITERAL_RE = re.compile(r'"wakuext_([A-Za-z0-9_]+)"')
_ANY_MENTION_RE = re.compile(r"wakuext_")
_PREFIX_SITE_RE = re.compile(r'"([A-Za-z0-9_]+)"\.prefix\b')
# Deliberately strict about the helper's exact shape: if the definition is
# reformatted this stops matching, the file's namespace becomes unresolvable,
# and the gate fails loudly — never a silent wrong-namespace resolution.
_PREFIX_DEF_RE = re.compile(
    r'proc prefix\*\(methodName: string\): string =\s*\n\s*result = "([A-Za-z0-9]+)_" & methodName'
)
# `import`/`include` line, or a continuation line of a block import that
# holds only the module path.
_UTILS_IMPORT_RE = re.compile(
    r"^\s*(?:import|include)\b[^\n]*app_service/common/utils"
    r"|^\s*[\w./]*app_service/common/utils\s*,?\s*$",
    re.M,
)
_ENTRY_ALT = r"(?:callPrivateRPC(?:NoDecode|Raw)?|makePrivateRpcCall(?:NoDecode)?)"
# Every occurrence of an entry token is counted; an occurrence whose argument
# the anchored regex cannot read becomes an unresolved site instead of
# silently producing no match (a call-shaped argument, for example).
_ENTRY_TOKEN_RE = re.compile(rf"\b{_ENTRY_ALT}\(")
_ENTRY_ARG_ANCHORED_RE = re.compile(rf"\b{_ENTRY_ALT}\(\s*([^,()]+?)\s*[,)]")
_RPC_TOKEN_RE = re.compile(r"^[ \t]*(rpc\()", re.M)
_RPC_MACRO_ANCHORED_RE = re.compile(r'rpc\(([A-Za-z0-9_]+),\s*"([A-Za-z0-9_]+)"\)')

_OTHER_NS_LITERAL_ARG_RE = re.compile(r'"[a-z0-9]+_[A-Za-z0-9_]+"')

# Entry-point arguments that are known not to be statically resolvable,
# pinned as (file, argument or site snippet). Both directions are enforced:
# a new unresolved site fails until listed here (or the parser learns its
# form), and a stale entry fails until removed.
_UNRESOLVED_ALLOWLIST: set[tuple[str, str]] = {
    # transport layer: forwards a caller-built JSON envelope or an
    # already-composed method name, not a new composition idiom
    ("src/backend/core.nim", "inputJSON"),
    ("src/backend/core.nim", "$inputJSON"),
    ("src/backend/core.nim", "methodName"),
    ("src/status_go.nim", "inputJSON.cstring"),
}

# Call sites that name a method the shipped status-go genuinely does not
# register, each pinned with its reason (cite the tracking issue once one
# exists). The gate stays green on the known break and fails on any new one;
# an entry whose method starts resolving is stale and fails until removed.
_KNOWN_MISSING: dict[str, str] = {
}

# Files where `wakuext_` appears in text beyond what the extractors account
# for (comments, log strings), pinned with the exact expected excess so an
# accepted mention in a file does not let a later composed call in the same
# file pass unchecked.
_MENTION_ALLOWLIST: dict[str, int] = {
    # class doc comment names wakuext_sendChatMessage; the file's actual call
    # sites are clean literals and are checked
    "mobile/android/qt6/src/app/status/mobile/ipc/NotificationReplyReceiver.java": 1,
    # error text names wakuext_peers; the actual call is checked via .prefix
    "src/app_service/service/general/service.nim": 1,
}

# These floors detect parser rot; they are not coverage targets. Set at ~80%
# of what each extraction class matches at baseline (21 / 146 / 16), so a
# regex or walk change that drops a meaningful share of a class fails even if
# every extracted name still resolves.
_CLASS_FLOORS = {"literal": 16, "prefix": 120, "rpc_macro": 12}


def _rpc_name(go_method: str) -> str:
    # geth RPC lowercases only the first rune of the method name.
    return go_method[:1].lower() + go_method[1:]


def registered_methods(status_go_root: Path = STATUS_GO_ROOT) -> set[str]:
    names: set[str] = set()
    for rel in _GO_API_RELPATHS:
        f = status_go_root / rel
        if f.is_file():
            names.update(_rpc_name(m) for m in _GO_METHOD_RE.findall(f.read_text()))
    return names


def _app_files(root: Path):
    # os.walk with in-place pruning: never descend vendor/, .git/, etc.
    # (rglob would enumerate them all before any filter could apply).
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in _SCAN_SKIP_DIRS]
        for filename in filenames:
            path = Path(dirpath) / filename
            if path.suffix not in _APP_SRC_SUFFIXES:
                continue
            if path.resolve() == _HERE:  # this file's own docstring examples
                continue
            yield path


def _nim_prefix_namespace(text: str) -> str | None:
    """Which namespace `"x".prefix` resolves to in this file, or None."""
    local = _PREFIX_DEF_RE.search(text)
    if local:
        return local.group(1)
    if _UTILS_IMPORT_RE.search(text):
        return "wakuext"
    return None


def _classify_entry_arg(arg: str, file_ns: str | None):
    """Classify an entry-point first argument.

    Returns ("wakuext", name) for an argument this gate must check,
    ("other", None) for a resolvable non-wakuext argument, or
    ("unresolved", None) when the form is not statically resolvable.
    """
    arg = arg.strip()
    m = _LITERAL_RE.fullmatch(arg)
    if m:
        return "wakuext", m.group(1)
    m = _PREFIX_SITE_RE.fullmatch(arg)
    if m:
        if file_ns == "wakuext":
            return "wakuext", m.group(1)
        if file_ns is not None:
            return "other", None
        return "unresolved", None
    if _OTHER_NS_LITERAL_ARG_RE.fullmatch(arg):
        return "other", None
    return "unresolved", None


def _first_line(text: str, start: int, limit: int = 60) -> str:
    return text[start:].split("\n", 1)[0][:limit].strip()


@lru_cache(maxsize=None)
def collect(app_root: Path = APP_ROOT):
    """Walk the app tree once and return everything the gates assert on:

    checked        {method name: [where it is named]} — must all resolve
    unresolved     {(relpath, site text)} — sites no extractor understands
    mentions       {relpath: excess} — unaccounted `wakuext_` text per file
    class_counts   {extraction class: matched site count}

    Cached per root: the gate tests all walk the same real tree, and the
    result is read-only by convention.
    """
    checked: dict[str, list[str]] = {}
    unresolved: set[tuple[str, str]] = set()
    mentions: dict[str, int] = {}
    class_counts = {"literal": 0, "prefix": 0, "rpc_macro": 0}

    def _add(name: str, where: str):
        checked.setdefault(name, []).append(where)

    for path in _app_files(app_root):
        text = path.read_text(errors="ignore")
        rel = str(path.relative_to(app_root))

        literals = _LITERAL_RE.findall(text)
        for name in literals:
            _add(name, f"{rel} (literal)")
        class_counts["literal"] += len(literals)
        accounted = len(literals) + len(_PREFIX_DEF_RE.findall(text))

        if path.suffix == ".nim":
            ns = _nim_prefix_namespace(text)
            prefix_sites = _PREFIX_SITE_RE.findall(text)
            if ns == "wakuext":
                for name in prefix_sites:
                    _add(name, f"{rel} (.prefix)")
                class_counts["prefix"] += len(prefix_sites)
            elif ns is None and prefix_sites:
                unresolved.update((rel, f'"{n}".prefix') for n in prefix_sites)

            for token in _RPC_TOKEN_RE.finditer(text):
                site = _RPC_MACRO_ANCHORED_RE.match(text, token.start(1))
                if site is None:
                    unresolved.add((rel, _first_line(text, token.start(1))))
                elif site.group(2) == "wakuext":
                    _add(site.group(1), f"{rel} (rpc macro)")
                    class_counts["rpc_macro"] += 1

            for token in _ENTRY_TOKEN_RE.finditer(text):
                arg_match = _ENTRY_ARG_ANCHORED_RE.match(text, token.start())
                if arg_match is None:
                    unresolved.add((rel, _first_line(text, token.start())))
                    continue
                kind, _name = _classify_entry_arg(arg_match.group(1), ns)
                if kind == "unresolved":
                    unresolved.add((rel, arg_match.group(1).strip()))

        excess = len(_ANY_MENTION_RE.findall(text)) - accounted
        if excess > 0:
            mentions[rel] = excess

    return checked, unresolved, mentions, class_counts


@pytest.mark.gate
def test_wakuext_namespace_wiring():
    api = STATUS_GO_ROOT / "services" / "wakuv2ext" / "api.go"
    svc = STATUS_GO_ROOT / "services" / "wakuv2ext" / "service.go"
    assert api.is_file() and svc.is_file(), (
        f"wakuv2ext sources missing under {STATUS_GO_ROOT} — is the status-go "
        f"submodule checked out?"
    )
    assert re.search(r"type PublicAPI struct \{[^}]*\*ext\.PublicAPI", api.read_text(), re.S), (
        "wakuv2ext.PublicAPI no longer embeds ext.PublicAPI — the registered-"
        "method union over ext + wakuv2ext is invalid; rework registered_methods()"
    )
    assert re.search(r'Namespace:\s*"wakuext"', svc.read_text()), (
        'wakuv2ext no longer registers the "wakuext" namespace — find where '
        "the namespace moved and update _GO_API_RELPATHS"
    )


@pytest.mark.gate
def test_wakuext_call_sites_resolve():
    registered = registered_methods()
    assert registered, (
        f"No wakuext methods parsed from {STATUS_GO_ROOT} — is the status-go "
        f"submodule checked out?"
    )
    checked, _, _, _ = collect()
    assert checked, (
        f"No wakuext call sites found under {APP_ROOT} — this would silently "
        f"pass, failing loudly instead"
    )
    missing = {n: w for n, w in checked.items()
               if n not in registered and n not in _KNOWN_MISSING}
    assert not missing, (
        "app names wakuext methods that the shipped status-go does not register "
        "(runtime 'method not found'):\n"
        + "\n".join(f"  wakuext_{n}  ← {', '.join(sorted(set(w)))}"
                    for n, w in sorted(missing.items()))
    )
    healed = {n for n in _KNOWN_MISSING if n in registered or n not in checked}
    assert not healed, (
        "stale _KNOWN_MISSING entries (method now registered, or the app call "
        "is gone) — delete them: " + ", ".join(sorted(healed))
    )


@pytest.mark.gate
def test_every_entry_arg_is_classified():
    _, unresolved, mentions, _ = collect()
    new = unresolved - _UNRESOLVED_ALLOWLIST
    assert not new, (
        "call sites no extractor understands — teach the parser this form, "
        "or add to _UNRESOLVED_ALLOWLIST with a reason:\n"
        + "\n".join(f"  {f}: {a}" for f, a in sorted(new))
    )
    stale = _UNRESOLVED_ALLOWLIST - unresolved
    assert not stale, (
        "stale _UNRESOLVED_ALLOWLIST entries (site changed or removed) — "
        "delete them:\n" + "\n".join(f"  {f}: {a}" for f, a in sorted(stale))
    )
    wrong_mentions = {f: n for f, n in mentions.items()
                      if _MENTION_ALLOWLIST.get(f) != n}
    assert not wrong_mentions, (
        "files mention wakuext_ beyond what the extractors account for "
        "(comment? log string? new idiom?) — check each, then extend the "
        "parser or pin the exact excess in _MENTION_ALLOWLIST:\n  "
        + "\n  ".join(f"{f}: excess {n} (pinned: {_MENTION_ALLOWLIST.get(f)})"
                      for f, n in sorted(wrong_mentions.items()))
    )
    stale_mentions = set(_MENTION_ALLOWLIST) - set(mentions)
    assert not stale_mentions, (
        "stale _MENTION_ALLOWLIST entries — delete them:\n  "
        + "\n  ".join(sorted(stale_mentions))
    )


@pytest.mark.gate
def test_extraction_floors():
    _, _, _, counts = collect()
    low = {c: (counts[c], floor) for c, floor in _CLASS_FLOORS.items()
           if counts[c] < floor}
    assert not low, (
        "an extraction class matches far fewer sites than reality — parser "
        "rot, not coverage change: "
        + ", ".join(f"{c}={n} (floor {f})" for c, (n, f) in sorted(low.items()))
    )


# ---------------------------------------------------------------------------
# Self-tests: prove on a synthetic tree that each extraction class turns the
# gate RED when status-go drops a method it names, and that each known bypass
# shape stays caught. These run with the gate.
# ---------------------------------------------------------------------------

_MINI_UTILS = (
    "proc prefix*(methodName: string): string =\n"
    '  result = "wakuext_" & methodName\n'
)


def _write(root: Path, rel: str, text: str):
    p = root / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)


def _mini_status_go(tmp_path: Path, methods=("KeptMethod",)) -> Path:
    go_root = tmp_path / "status-go"
    ext = "\n".join(f"func (api *PublicAPI) {m}(ctx context.Context) {{}}" for m in methods)
    _write(go_root, "services/ext/api.go", ext + "\n")
    _write(go_root, "services/wakuv2ext/api.go",
           "type PublicAPI struct {\n\t*ext.PublicAPI\n\tservice *Service\n}\n")
    _write(go_root, "services/wakuv2ext/service.go", 'Namespace: "wakuext",\n')
    return go_root


def _missing(app_root: Path, go_root: Path) -> set[str]:
    checked, _, _, _ = collect(app_root)
    return {n for n in checked if n not in registered_methods(go_root)}


def _unresolved(app_root: Path) -> set[tuple[str, str]]:
    return collect(app_root)[1]


def test_selftest_literal_site_goes_red(tmp_path):
    _write(tmp_path / "app", "src/thing.qml", 'call("wakuext_droppedMethod")\n')
    go = _mini_status_go(tmp_path)
    assert _missing(tmp_path / "app", go) == {"droppedMethod"}


def test_selftest_prefix_site_goes_red(tmp_path):
    app = tmp_path / "app"
    _write(app, "src/app_service/common/utils.nim", _MINI_UTILS)
    _write(app, "src/backend/chat.nim",
           "import core, ../app_service/common/utils\n"
           'let r = callPrivateRPC("droppedMethod".prefix, payload)\n'
           'let ok = callPrivateRPC("keptMethod".prefix, payload)\n')
    go = _mini_status_go(tmp_path, methods=("KeptMethod",))
    assert _missing(app, go) == {"droppedMethod"}


def test_selftest_rpc_macro_site_goes_red(tmp_path):
    app = tmp_path / "app"
    _write(app, "src/backend/backend.nim",
           'rpc(droppedMethod, "wakuext"):\n  discard\n'
           'rpc(somethingElse, "wallet"):\n  discard\n')
    go = _mini_status_go(tmp_path)
    assert _missing(app, go) == {"droppedMethod"}


def test_selftest_non_wakuext_prefix_not_flagged(tmp_path):
    app = tmp_path / "app"
    _write(app, "src/backend/linkpreview.nim",
           "proc prefix*(methodName: string): string =\n"
           '  result = "linkpreview_" & methodName\n'
           'let r = callPrivateRPC("unfurl".prefix, payload)\n')
    go = _mini_status_go(tmp_path)
    assert _missing(app, go) == set()


def test_selftest_unknown_entry_arg_is_caught(tmp_path):
    app = tmp_path / "app"
    _write(app, "src/backend/dynamic.nim",
           "let m = composeName()\ndiscard callPrivateRPC(m, payload)\n")
    assert ("src/backend/dynamic.nim", "m") in _unresolved(app)


def test_selftest_call_shaped_entry_arg_is_caught(tmp_path):
    # a parenthesised argument never matches the arg regex; the occurrence
    # count must surface it anyway
    app = tmp_path / "app"
    _write(app, "src/backend/dynamic.nim",
           "discard callPrivateRPC(composeName(chatId), payload)\n")
    assert any(f == "src/backend/dynamic.nim" for f, _ in _unresolved(app))


def test_selftest_make_private_rpc_call_is_an_entry_point(tmp_path):
    # the lower-level transport proc is callable directly
    app = tmp_path / "app"
    _write(app, "src/backend/sneaky.nim",
           "discard makePrivateRpcCall(m, inputJSON)\n")
    assert ("src/backend/sneaky.nim", "m") in _unresolved(app)


def test_selftest_rpc_macro_nonliteral_namespace_is_caught_per_site(tmp_path):
    # rpc() with a const namespace never matches the macro regex; each such
    # site must be reported separately, so pinning one cannot hide the next
    app = tmp_path / "app"
    _write(app, "src/backend/backend.nim",
           'const ns = "wakuext"\n'
           "rpc(hiddenOne, ns):\n  discard\n"
           "rpc(hiddenTwo, ns):\n  discard\n")
    unresolved = _unresolved(app)
    assert ("src/backend/backend.nim", "rpc(hiddenOne, ns):") in unresolved
    assert ("src/backend/backend.nim", "rpc(hiddenTwo, ns):") in unresolved


def test_selftest_cpp_and_ts_literals_are_checked(tmp_path):
    _write(tmp_path / "app", "src/native/bridge.cpp",
           'call("wakuext_droppedNativeMethod");\n')
    _write(tmp_path / "app", "src/bridge/api.ts",
           'rpc("wakuext_droppedTsMethod")\n')
    go = _mini_status_go(tmp_path)
    assert _missing(tmp_path / "app", go) == {"droppedNativeMethod",
                                              "droppedTsMethod"}


def test_selftest_include_and_block_import_resolve_prefix(tmp_path):
    app = tmp_path / "app"
    _write(app, "src/app_service/common/utils.nim", _MINI_UTILS)
    _write(app, "src/backend/via_include.nim",
           "include app_service/common/utils\n"
           'let r = callPrivateRPC("droppedViaInclude".prefix, payload)\n')
    _write(app, "src/backend/via_block.nim",
           "import\n  core,\n  ../app_service/common/utils\n"
           'let r = callPrivateRPC("droppedViaBlock".prefix, payload)\n')
    go = _mini_status_go(tmp_path)
    assert _missing(app, go) == {"droppedViaInclude", "droppedViaBlock"}


def test_selftest_go_receiver_name_is_not_hardcoded(tmp_path):
    go_root = tmp_path / "status-go"
    _write(go_root, "services/ext/api.go",
           "func (a *PublicAPI) RenamedReceiverMethod(ctx context.Context) {}\n")
    assert registered_methods(go_root) == {"renamedReceiverMethod"}


def test_selftest_mention_excess_is_counted_per_file(tmp_path):
    # one pinned comment mention must not let a later composed call in the
    # same file pass unchecked
    app = tmp_path / "app"
    _write(app, "src/Replies.java",
           "// replies go through wakuext_sendChatMessage\n"
           'String method = "wakuext_" + dynamicName;\n')
    _, _, mentions, _ = collect(app)
    assert mentions == {"src/Replies.java": 2}
