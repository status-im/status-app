"""Static guard on the wakuext FFI seam.

The app sends `{"method": "wakuext_<name>"}` to status-go, which resolves the
method by name at runtime. Renaming or removing a `wakuext` method there breaks
every app call site that names it — no compile error, no test unless one hits
that exact call. This asserts every static `"wakuext_<name>"` literal in the app
resolves to a method the vendored status-go (the shipped pin) registers.

Name-existence only: a method that exists but changed its params, or a
subscription (callable as `wakuext_subscribe`), is out of scope — the registered
set is a superset of the truly-callable one. Runtime-composed names
(`"wakuext_" & x`, `fmt"wakuext_{x}"`) can't be checked statically; they're
reported as blind spots rather than skipped.
"""
from __future__ import annotations

import os
import re
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve()
APP_ROOT = Path(os.environ.get("APP_ROOT", _HERE.parents[2]))
STATUS_GO_ROOT = Path(os.environ.get("STATUS_GO_ROOT", APP_ROOT / "vendor" / "status-go"))

# wakuv2ext serves the `wakuext` namespace; its PublicAPI embeds ext's. The parser
# assumes receiver `api` in these two files — a rename/split there under-counts
# (false FAIL, never a false pass).
_GO_API_FILES = [
    STATUS_GO_ROOT / "services" / "ext" / "api.go",
    STATUS_GO_ROOT / "services" / "wakuv2ext" / "api.go",
]
# Scan the whole tree so a call site in a new location (e.g. mobile/ios) can't
# silently drop out; over-scanning only risks a false FAIL.
_APP_SRC_SUFFIXES = {".nim", ".java", ".kt", ".swift", ".m", ".mm", ".qml", ".js"}
_SCAN_SKIP_DIRS = {"vendor", ".git", "build", "node_modules", "result", ".cache"}

_GO_METHOD_RE = re.compile(r"^func \(api \*PublicAPI\) ([A-Z][A-Za-z0-9]*)\(", re.M)
_CALL_SITE_RE = re.compile(r'"wakuext_([A-Za-z0-9_]+)"')
_ANY_MENTION_RE = re.compile(r"wakuext_")


def _rpc_name(go_method: str) -> str:
    # geth RPC lowercases only the first rune of the method name.
    return go_method[:1].lower() + go_method[1:]


def registered_methods(roots=_GO_API_FILES) -> set[str]:
    names: set[str] = set()
    for f in roots:
        if f.is_file():
            names.update(_rpc_name(m) for m in _GO_METHOD_RE.findall(f.read_text()))
    return names


def _app_files(root=APP_ROOT):
    for path in root.rglob("*"):
        if path.suffix not in _APP_SRC_SUFFIXES or not path.is_file():
            continue
        if _SCAN_SKIP_DIRS & set(path.relative_to(root).parts):
            continue
        if path.resolve() == _HERE:  # skip this test's own docstring examples
            continue
        yield path


def call_sites(root=APP_ROOT):
    """Return (literals, blind_spots): resolvable `"wakuext_<name>"` calls as
    {name: [files]}, and files whose `wakuext_` mentions aren't all clean
    literals (runtime-composed, interpolated, or a comment) — reported, not
    resolved, so no non-static form vanishes unseen."""
    literals: dict[str, list[str]] = {}
    blind: list[str] = []
    for path in _app_files(root):
        text = path.read_text(errors="ignore")
        clean = _CALL_SITE_RE.findall(text)
        rel = str(path.relative_to(root))
        for name in clean:
            literals.setdefault(name, []).append(rel)
        if len(_ANY_MENTION_RE.findall(text)) > len(clean):
            blind.append(rel)
    return literals, sorted(set(blind))


@pytest.mark.gate
def test_wakuext_call_sites_resolve():
    registered = registered_methods()
    assert registered, (
        f"No wakuext methods parsed from {STATUS_GO_ROOT} — is the status-go "
        f"submodule checked out? (set STATUS_GO_ROOT)"
    )
    literals, _ = call_sites()
    assert literals, (
        f"No wakuext_ call sites found under {APP_ROOT} — is APP_ROOT the app "
        f"checkout? (this would silently pass — failing loudly instead)"
    )
    missing = {n: f for n, f in literals.items() if n not in registered}
    assert not missing, (
        "app calls wakuext methods that the shipped status-go does not register "
        "(runtime 'method not found'):\n"
        + "\n".join(f"  wakuext_{n}  ← {', '.join(sorted(set(f)))}"
                    for n, f in sorted(missing.items()))
    )


def test_report_blind_spots(capsys):
    _, blind = call_sites()
    if blind:
        with capsys.disabled():
            print("\nwakuext blind spots (mentions not statically resolved):\n  " +
                  "\n  ".join(blind))
