"""Static guard on the wakuext, wallet and accounts FFI seam.

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

The `wallet` and `accounts` namespaces are checked the same way through forms
1 and 3; the `.prefix` form is wakuext-only.

Coverage is guarded from both ends: extracted names must resolve, and every
occurrence of a private-RPC entry point must yield an argument the parser can
classify — an unreadable one counts as unresolved and must be pinned in
_UNRESOLVED_ALLOWLIST, so within the scanned suffixes and entry points a new
composition idiom turns the gate red instead of shrinking coverage silently.
"""
from __future__ import annotations

import os
from collections import Counter
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
#
# status-go f9cc782a6 moved RPC services from services/ to pkg/services/.
# Keep _mini_status_go and the wiring test on this same prefix.
_GO_SERVICES_DIR = "pkg/services"
# namespace -> (API source files, receiver type, service.go that registers it,
# constructor its APIs() entry passes as Service)
_NAMESPACES = {
    "wakuext": (("ext/api.go", "wakuv2ext/api.go"), "PublicAPI",
                "wakuv2ext/service.go", None),
    "wallet": (("wallet/api.go",), "API", "wallet/service.go", "NewAPI"),
    "accounts": (("accounts/accounts.go",), "API", "accounts/service.go",
                 "AccountsAPI"),
}
_NEW_NAMESPACES = tuple(ns for ns in _NAMESPACES if ns != "wakuext")

# Scan the whole tree so a call site in a new location (e.g. mobile/ios) can't
# silently drop out; over-scanning only risks a false FAIL.
_APP_SRC_SUFFIXES = {".nim", ".java", ".kt", ".swift", ".m", ".mm", ".qml",
                     ".js", ".jsx", ".mjs", ".ts", ".tsx", ".cpp", ".cc",
                     ".h", ".hpp"}
_SCAN_SKIP_DIRS = {"vendor", ".git", "build", "node_modules", "result", ".cache",
                     ".claude"}

_GO_METHOD_RES = {
    ns: re.compile(rf"^func \(\w+ \*{recv}\) ([A-Z][A-Za-z0-9]*)\(", re.M)
    for ns, (_, recv, _, _) in _NAMESPACES.items()
}
_LITERAL_RES = {ns: re.compile(rf'"{ns}_([A-Za-z0-9_]+)"') for ns in _NAMESPACES}
# `wallet_`/`accounts_` are common identifier stems, so only a string that
# starts with the namespace counts as a mention of the RPC name.
_ANY_MENTION_RES = {"wakuext": re.compile(r"wakuext_")} | {
    ns: re.compile(rf"[\"']{ns}_") for ns in _NEW_NAMESPACES
}
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

# Methods the shipped status-go genuinely does not register, each pinned to
# the exact set of sites allowed to name it. A second site for the same method
# is a new call to a method that does not exist, and fails; an entry whose
# method starts resolving, or whose sites change, is stale and fails until
# updated. Cite the tracking issue once one exists.
_KNOWN_MISSING: dict[str, dict[str, frozenset[str]]] = {
    "wallet": {
        "checkConnected": frozenset({"src/backend/backend.nim (rpc macro)"}),
        "getWalletToken": frozenset({"src/backend/backend.nim (rpc macro)"}),
        "getCollectiblesByUniqueID": frozenset({"src/backend/collectibles.nim (rpc macro)"}),
        "getCollectiblesByOwnerWithCursor": frozenset({"src/backend/collectibles.nim (rpc macro)"}),
        "getCollectiblesByOwnerAndContractAddressWithCursor": frozenset({"src/backend/collectibles.nim (rpc macro)"}),
    },
}

# (file, namespace) pairs where the namespace appears in text beyond what the
# extractors account for (comments, log strings), pinned with the exact
# expected excess so an accepted mention in a file does not let a later
# composed call in the same file pass unchecked.
_MENTION_ALLOWLIST: dict[tuple[str, str], int] = {
    # class doc comment names wakuext_sendChatMessage; the file's actual call
    # sites are clean literals and are checked
    ("mobile/android/qt6/src/app/status/mobile/ipc/NotificationReplyReceiver.java",
     "wakuext"): 1,
    # error text names wakuext_peers; the actual call is checked via .prefix
    ("src/app_service/service/general/service.nim", "wakuext"): 1,
}

# These floors detect parser rot; they are not coverage targets. Set at ~80%
# of what each extraction class matches at baseline (21 / 146 / 16), so a
# regex or walk change that drops a meaningful share of a class fails even if
# every extracted name still resolves.
_CLASS_FLOORS = {
    "wakuext": {"literal": 16, "prefix": 120, "rpc_macro": 12},
    # measured on upstream/master 2969f8bf1d6: literal 16, rpc_macro 57
    "wallet": {"literal": 13, "rpc_macro": 45},
    # measured on upstream/master 2969f8bf1d6: literal 25, rpc_macro 7
    "accounts": {"literal": 20, "rpc_macro": 5},
}


def _unexplained(checked: dict[str, list[str]], registered: set[str],
                 known: dict[str, frozenset[str]]) -> dict[str, list[str]]:
    """Names status-go does not register, unless the sites naming them are exactly
    the pinned ones, once each. Counted, not set: a second declaration in a pinned
    file is a new site with the same label."""
    return {n: w for n, w in checked.items()
            if n not in registered and Counter(w) != Counter(known.get(n, ()))}


def _rpc_name(go_method: str) -> str:
    # geth RPC lowercases only the first rune of the method name.
    return go_method[:1].lower() + go_method[1:]


def registered_methods(status_go_root: Path = STATUS_GO_ROOT,
                       ns: str = "wakuext") -> set[str]:
    names: set[str] = set()
    for rel in _NAMESPACES[ns][0]:
        f = status_go_root / _GO_SERVICES_DIR / rel
        if f.is_file():
            names.update(_rpc_name(m) for m in _GO_METHOD_RES[ns].findall(f.read_text()))
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
    m = _LITERAL_RES["wakuext"].fullmatch(arg)
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

    checked        {namespace: {method name: [where it is named]}} — must
                   all resolve
    unresolved     {(relpath, site text)} — sites no extractor understands
    mentions       {(relpath, namespace): excess} — unaccounted namespace text
    class_counts   {namespace: {extraction class: matched site count}}

    Cached per root: the gate tests all walk the same real tree, and the
    result is read-only by convention.
    """
    checked: dict[str, dict[str, list[str]]] = {ns: {} for ns in _NAMESPACES}
    unresolved: set[tuple[str, str]] = set()
    mentions: dict[tuple[str, str], int] = {}
    class_counts = {ns: {"literal": 0, "prefix": 0, "rpc_macro": 0}
                    for ns in _NAMESPACES}

    def _add(ns: str, name: str, where: str):
        checked[ns].setdefault(name, []).append(where)

    for path in _app_files(app_root):
        text = path.read_text(errors="ignore")
        rel = str(path.relative_to(app_root))

        accounted = {}
        for lit_ns, lit_re in _LITERAL_RES.items():
            literals = lit_re.findall(text)
            for name in literals:
                _add(lit_ns, name, f"{rel} (literal)")
            class_counts[lit_ns]["literal"] += len(literals)
            accounted[lit_ns] = len(literals)
        accounted["wakuext"] += len(_PREFIX_DEF_RE.findall(text))

        if path.suffix == ".nim":
            ns = _nim_prefix_namespace(text)
            prefix_sites = _PREFIX_SITE_RE.findall(text)
            if ns == "wakuext":
                for name in prefix_sites:
                    _add("wakuext", name, f"{rel} (.prefix)")
                class_counts["wakuext"]["prefix"] += len(prefix_sites)
            elif ns is None and prefix_sites:
                unresolved.update((rel, f'"{n}".prefix') for n in prefix_sites)

            for token in _RPC_TOKEN_RE.finditer(text):
                site = _RPC_MACRO_ANCHORED_RE.match(text, token.start(1))
                if site is None:
                    unresolved.add((rel, _first_line(text, token.start(1))))
                elif site.group(2) in _NAMESPACES:
                    _add(site.group(2), site.group(1), f"{rel} (rpc macro)")
                    class_counts[site.group(2)]["rpc_macro"] += 1

            for token in _ENTRY_TOKEN_RE.finditer(text):
                arg_match = _ENTRY_ARG_ANCHORED_RE.match(text, token.start())
                if arg_match is None:
                    unresolved.add((rel, _first_line(text, token.start())))
                    continue
                kind, _name = _classify_entry_arg(arg_match.group(1), ns)
                if kind == "unresolved":
                    unresolved.add((rel, arg_match.group(1).strip()))

        for mention_ns, mention_re in _ANY_MENTION_RES.items():
            excess = len(mention_re.findall(text)) - accounted[mention_ns]
            if excess > 0:
                mentions[(rel, mention_ns)] = excess

    return checked, unresolved, mentions, class_counts


@pytest.mark.gate
def test_wakuext_namespace_wiring():
    api = STATUS_GO_ROOT / _GO_SERVICES_DIR / "wakuv2ext" / "api.go"
    svc = STATUS_GO_ROOT / _GO_SERVICES_DIR / "wakuv2ext" / "service.go"
    assert api.is_file() and svc.is_file(), (
        f"wakuv2ext sources missing under {STATUS_GO_ROOT / _GO_SERVICES_DIR} — "
        f"is the status-go submodule checked out, or did the layout move?"
    )
    assert re.search(r"type PublicAPI struct \{[^}]*\*ext\.PublicAPI", api.read_text(), re.S), (
        "wakuv2ext.PublicAPI no longer embeds ext.PublicAPI — the registered-"
        "method union over ext + wakuv2ext is invalid; rework registered_methods()"
    )
    assert re.search(r'Namespace:\s*"wakuext"', svc.read_text()), (
        'wakuv2ext no longer registers the "wakuext" namespace — find where '
        "the namespace moved and update _NAMESPACES"
    )


@pytest.mark.gate
@pytest.mark.parametrize("ns", _NEW_NAMESPACES)
def test_namespace_registered(ns):
    _, recv, service_rel, ctor = _NAMESPACES[ns]
    svc = STATUS_GO_ROOT / _GO_SERVICES_DIR / service_rel
    assert svc.is_file(), f"{svc} missing — did the layout move?"
    assert re.search(rf'Namespace:\s*"{ns}",[^}}]*?Service:\s*(?:s\.)?{ctor}\(',
                     svc.read_text()), (
        f'{service_rel} no longer registers "{ns}" with {ctor}() — find what '
        f"serves the namespace now and update _NAMESPACES"
    )
    pkg = svc.parent
    assert any(re.search(rf"^func (?:\([^)]*\) )?{ctor}\([^)]*\) \*{recv}\b",
                         f.read_text(), re.M) for f in pkg.glob("*.go")), (
        f"{ctor}() no longer returns *{recv} — the receiver in _NAMESPACES "
        f"is wrong for {ns}"
    )


@pytest.mark.gate
@pytest.mark.parametrize("ns", _NAMESPACES)
def test_call_sites_resolve(ns):
    registered = registered_methods(ns=ns)
    assert registered, (
        f"No {ns} methods parsed from {STATUS_GO_ROOT} — is the status-go "
        f"submodule checked out?"
    )
    checked = collect()[0][ns]
    assert checked, (
        f"No {ns} call sites found under {APP_ROOT} — this would silently "
        f"pass, failing loudly instead"
    )
    known = _KNOWN_MISSING.get(ns, {})
    missing = _unexplained(checked, registered, known)
    assert not missing, (
        f"app names {ns} methods that the shipped status-go does not register "
        "(runtime 'method not found'):\n"
        + "\n".join(f"  {ns}_{n}  ← {', '.join(sorted(set(w)))}"
                    for n, w in sorted(missing.items()))
    )
    healed = {n for n in known if n in registered or n not in checked}
    assert not healed, (
        "stale _KNOWN_MISSING entries (method now registered, or the app call "
        "is gone) — delete them: " + ", ".join(sorted(healed))
    )
    moved = {n for n, sites in known.items()
             if n in checked and n not in registered and set(checked[n]) < sites}
    assert not moved, (
        "stale _KNOWN_MISSING sites (a pinned site no longer names the method) "
        "— update them: " + ", ".join(sorted(moved))
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
    wrong_mentions = {k: n for k, n in mentions.items()
                      if _MENTION_ALLOWLIST.get(k) != n}
    assert not wrong_mentions, (
        "files mention a namespace beyond what the extractors account for "
        "(comment? log string? new idiom?) — check each, then extend the "
        "parser or pin the exact excess in _MENTION_ALLOWLIST:\n  "
        + "\n  ".join(f"{f} [{ns}]: excess {n} (pinned: {_MENTION_ALLOWLIST.get((f, ns))})"
                      for (f, ns), n in sorted(wrong_mentions.items()))
    )
    stale_mentions = set(_MENTION_ALLOWLIST) - set(mentions)
    assert not stale_mentions, (
        "stale _MENTION_ALLOWLIST entries — delete them:\n  "
        + "\n  ".join(f"{f} [{ns}]" for f, ns in sorted(stale_mentions))
    )


@pytest.mark.gate
@pytest.mark.parametrize("ns", _NAMESPACES)
def test_extraction_floors(ns):
    counts = collect()[3][ns]
    low = {c: (counts[c], floor) for c, floor in _CLASS_FLOORS[ns].items()
           if counts[c] < floor}
    assert not low, (
        "an extraction class matches far fewer sites than reality — parser "
        f"rot, not coverage change ({ns}): "
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


def _mini_status_go(tmp_path: Path, methods=("KeptMethod",), ns="wakuext") -> Path:
    go_root = tmp_path / "status-go"
    api_rels, recv, _, _ = _NAMESPACES[ns]
    api = "\n".join(f"func (api *{recv}) {m}(ctx context.Context) {{}}" for m in methods)
    _write(go_root, f"{_GO_SERVICES_DIR}/{api_rels[0]}", api + "\n")
    if ns == "wakuext":
        _write(go_root, f"{_GO_SERVICES_DIR}/wakuv2ext/api.go",
               "type PublicAPI struct {\n\t*ext.PublicAPI\n\tservice *Service\n}\n")
        _write(go_root, f"{_GO_SERVICES_DIR}/wakuv2ext/service.go", 'Namespace: "wakuext",\n')
    return go_root


def _missing(app_root: Path, go_root: Path, ns: str = "wakuext") -> set[str]:
    checked = collect(app_root)[0][ns]
    return {n for n in checked if n not in registered_methods(go_root, ns)}


def _unresolved(app_root: Path) -> set[tuple[str, str]]:
    return collect(app_root)[1]


def test_selftest_literal_site_goes_red(tmp_path):
    _write(tmp_path / "app", "src/thing.qml", 'call("wakuext_droppedMethod")\n')
    go = _mini_status_go(tmp_path)
    assert _missing(tmp_path / "app", go) == {"droppedMethod"}


@pytest.mark.parametrize("ns", _NEW_NAMESPACES)
def test_selftest_namespace_site_goes_red(tmp_path, ns):
    app = tmp_path / "app"
    _write(app, "src/backend/backend.nim",
           f'rpc(droppedRpc, "{ns}"):\n  discard\n'
           f'rpc(keptMethod, "{ns}"):\n  discard\n'
           f'let r = callPrivateRPC("{ns}_droppedLiteral", payload)\n'
           f'let ok = callPrivateRPC("{ns}_keptMethod", payload)\n')
    go = _mini_status_go(tmp_path, methods=("KeptMethod",), ns=ns)
    assert _missing(app, go, ns) == {"droppedRpc", "droppedLiteral"}


def test_selftest_known_missing_second_site_goes_red(tmp_path):
    known = _KNOWN_MISSING["wallet"]
    go = _mini_status_go(tmp_path, ns="wallet")
    registered = registered_methods(go, "wallet")
    pinned = tmp_path / "pinned"
    _write(pinned, "src/backend/backend.nim", 'rpc(checkConnected, "wallet"):\n  discard\n')
    assert not _unexplained(collect(pinned)[0]["wallet"], registered, known)
    second = tmp_path / "second"
    _write(second, "src/backend/backend.nim", 'rpc(checkConnected, "wallet"):\n  discard\n')
    _write(second, "src/backend/other.nim", 'rpc(checkConnected, "wallet"):\n  discard\n')
    assert set(_unexplained(collect(second)[0]["wallet"], registered, known)) == {"checkConnected"}
    twice = tmp_path / "twice"
    _write(twice, "src/backend/backend.nim",
           'rpc(checkConnected, "wallet"):\n  discard\n'
           'rpc(checkConnected, "wallet"):\n  discard\n')
    assert set(_unexplained(collect(twice)[0]["wallet"], registered, known)) == {"checkConnected"}


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
    _write(go_root, f"{_GO_SERVICES_DIR}/ext/api.go",
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
    assert mentions == {("src/Replies.java", "wakuext"): 2}
