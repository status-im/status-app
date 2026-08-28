"""Locator references must resolve.

A page object naming a locator that no longer exists fails with an
AttributeError in the middle of a device run, far from the change that removed
it. These tests catch it without a device, in under a second.
"""

import ast
import os
from pathlib import Path
from unittest.mock import MagicMock

import pytest

from locators.app_locators import AppLocators
from pages.app import App

E2E_ROOT = Path(__file__).resolve().parents[1]


@pytest.mark.gate
@pytest.mark.component
def test_nav_recovery_probes_a_defined_locator(monkeypatch):
    """Drive the recovery path that runs after the introduce-yourself sheet.

    An ordinary run skips this branch, because it needs the navigation bar to
    be missing and the sheet to be up. Assert the locator it probes, not just
    that it returns True.
    """
    app = App(MagicMock())
    probed = []

    def fake_is_element_visible(locator, timeout=None):
        probed.append(locator)
        return len(probed) > 1

    monkeypatch.setattr(app, "is_element_visible", fake_is_element_visible)
    monkeypatch.setattr(
        "utils.screen_identity.dismiss_introduce_yourself", lambda *a, **k: True
    )

    assert app._ensure_main_nav_visible() is True
    assert len(probed) == 2, "the probe after the sheet was dismissed did not run"
    assert probed[1] == AppLocators.PROFILE_NAV_BUTTON


def _parse_tree():
    """Return {path: module ast} for every file we can parse."""
    trees = {}
    for dirpath, _, filenames in os.walk(E2E_ROOT):
        for name in filenames:
            if not name.endswith(".py"):
                continue
            path = Path(dirpath) / name
            try:
                trees[path] = ast.parse(path.read_text())
            except SyntaxError:
                continue
    return trees


def _class_attributes(node):
    names = set()
    for stmt in node.body:
        if isinstance(stmt, ast.Assign):
            names |= {t.id for t in stmt.targets if isinstance(t, ast.Name)}
        elif isinstance(stmt, ast.AnnAssign) and isinstance(stmt.target, ast.Name):
            names.add(stmt.target.id)
        elif isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef)):
            names.add(stmt.name)
    return names


def _locator_classes(trees):
    """Return {class name: (base names, own attribute names)} for locator classes."""
    classes = {}
    for path, tree in trees.items():
        if "locators" not in path.relative_to(E2E_ROOT).parts:
            continue
        for node in ast.walk(tree):
            if isinstance(node, ast.ClassDef):
                bases = [b.id for b in node.bases if isinstance(b, ast.Name)]
                classes[node.name] = (bases, _class_attributes(node))
    return classes


def _resolve(name, classes, seen=None):
    """Return every attribute a locator class offers, inherited ones included."""
    seen = seen or set()
    if name in seen or name not in classes:
        return set()
    seen.add(name)
    bases, own = classes[name]
    return set(own).union(*(_resolve(b, classes, seen) for b in bases), set())


def _locator_bindings(trees, locator_classes):
    """Map each class to its bases and its ``self.<attr> = SomeLocators()`` binds."""
    owners = {}
    for path, tree in trees.items():
        for node in ast.walk(tree):
            if not isinstance(node, ast.ClassDef):
                continue
            binds = {}
            for stmt in ast.walk(node):
                if (
                    isinstance(stmt, ast.Assign)
                    and len(stmt.targets) == 1
                    and isinstance(stmt.targets[0], ast.Attribute)
                    and isinstance(stmt.targets[0].value, ast.Name)
                    and stmt.targets[0].value.id == "self"
                    and isinstance(stmt.value, ast.Call)
                    and isinstance(stmt.value.func, ast.Name)
                    and stmt.value.func.id in locator_classes
                ):
                    binds[stmt.targets[0].attr] = stmt.value.func.id
            bases = {b.id for b in node.bases if isinstance(b, ast.Name)}
            owners[node.name] = (bases, binds, node, path)
    return owners


def _binding_for(class_name, attr, owners, seen=None):
    seen = seen or set()
    if class_name in seen or class_name not in owners:
        return None
    seen.add(class_name)
    bases, binds, _, _ = owners[class_name]
    if attr in binds:
        return binds[attr]
    for base in bases:
        found = _binding_for(base, attr, owners, seen)
        if found:
            return found
    return None


@pytest.mark.gate
@pytest.mark.component
def test_no_references_to_undefined_locators():
    """Flag every locator attribute no locator class defines.

    Each ``self.<attr>.NAME`` is checked against the class that ``<attr>`` is
    bound to, so a name defined only on some other locator class still fails.
    """
    trees = _parse_tree()
    classes = _locator_classes(trees)
    assert classes, "no locator classes found"
    resolved = {name: _resolve(name, classes) for name in classes}
    any_locator = set().union(*resolved.values())
    owners = _locator_bindings(trees, classes)

    findings = []
    for class_name, (_, _, node, path) in owners.items():
        rel = path.relative_to(E2E_ROOT)
        for ref in ast.walk(node):
            if not (
                isinstance(ref, ast.Attribute)
                and ref.attr.isupper()
                and isinstance(ref.value, ast.Attribute)
                and isinstance(ref.value.value, ast.Name)
                and ref.value.value.id == "self"
            ):
                continue
            owner = _binding_for(class_name, ref.value.attr, owners)
            if owner is not None:
                if ref.attr not in resolved[owner]:
                    findings.append(
                        f"{rel}:{ref.lineno} {class_name}.{ref.value.attr}"
                        f" ({owner}) has no {ref.attr}"
                    )
            elif ref.value.attr.endswith("locators") and ref.attr not in any_locator:
                findings.append(f"{rel}:{ref.lineno} self.{ref.value.attr}.{ref.attr}")

    assert not findings, "undefined locator references:\n  " + "\n  ".join(findings)
