#!/usr/bin/env python3
"""Click-contract checker (AST, two-pass).

Contract: click() raises on failure and only ever returns True (True = input
dispatched, not UI reacted); try_click() returns bool and never raises for
interaction failures. Suite-defined ``-> bool`` methods are either
best-effort (BEST_EFFORT names: ignoring the result is legal) or
outcome-reporting (result MUST be consumed: assert/if/return/assign).

Rules: R-CONSUME (branch/assert/assign/augassign/walrus/not/while/short-circuit
on raising click());
R-ELEMENT (branching on zero-arg WebElement.click(), returns None);
R-WRAPPER (any def whose tail returns raising click());
R-ALWAYS-TRUE (bool-annotated def, every return literal True, body contains a
bare raising click()); R-IGNORED (statement-level call of an indexed
outcome-reporting bool method); R-CONFLICT (same method name indexed with
conflicting contracts); safe_click token ban.

Accepted false negatives: ``_ = x()`` discards; await/dynamic edge cases below;
dynamic dispatch/getattr; contracts of methods called through variables;
bare raising clicks inside bool functions without a returning tail;
decorator-altered return contracts.

Standalone: python3 scripts/check_click_contract.py  (root = the e2e_appium
tree this file lives in — never the CWD). Wired into pytest sessionstart.
"""
import ast
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SKIP_DIRS = {".venv", "venv", "env", "__pycache__", "node_modules", ".git", "reports",
             "scripts", "cli", "locators"}  # tooling + locator factories — outside the click-contract domain
SKIP_REL = {"scripts/check_click_contract.py"}
CLICK = "click"

BEST_EFFORT_PREFIXES = (
    "try_", "is_", "has_", "wait_", "ensure_", "scroll_", "dismiss_", "hide_",
    "swipe_", "tap", "activation_", "activate_", "terminate_", "find_", "close",
    "_try_", "_is_", "_has_", "_wait_", "_ensure_", "_scroll_", "_dismiss_",
    "_hide_", "_swipe_", "_tap", "_activation_", "_activate_", "_close",
    "_find_", "_terminate_",
)
BEST_EFFORT_NAMES = {
    "hide_keyboard", "element_tap", "double_tap", "long_press_element",
    "perform_initial_activation", "select_maybe_later", "dismiss_if_present",
    "restart_app", "restart_app_with_data_cleared",
}


def best_effort(name: str) -> bool:
    return name in BEST_EFFORT_NAMES or name.startswith(BEST_EFFORT_PREFIXES)


def is_click_call(node):
    return (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
            and node.func.attr == CLICK)


def has_args(call):
    return bool(call.args or call.keywords)


def is_bool_annotation(returns):
    if isinstance(returns, ast.Name) and returns.id == "bool":
        return True
    if isinstance(returns, ast.Constant) and returns.value == "bool":
        return True
    return False


class Indexer(ast.NodeVisitor):
    """Pass 1: name -> set of contracts ('bool', 'always_true_bare_click')."""

    def __init__(self):
        self.bool_methods = {}   # name -> True
        self.conflicts = {}      # name -> set of contract kinds seen

    def visit_FunctionDef(self, node):
        self._handle(node)
        self.generic_visit(node)

    visit_AsyncFunctionDef = visit_FunctionDef

    def _handle(self, node):
        kind = "bool" if is_bool_annotation(node.returns) else "other"
        self.conflicts.setdefault(node.name, set()).add(kind)
        if kind == "bool":
            self.bool_methods[node.name] = True


def own_nodes(func):
    """Walk a function body WITHOUT descending into nested function defs."""
    stack = list(func.body)
    while stack:
        n = stack.pop()
        yield n
        if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda)):
            continue
        stack.extend(ast.iter_child_nodes(n))


class Checker(ast.NodeVisitor):
    def __init__(self, relpath, index):
        self.rel, self.index, self.bad, self.seen = relpath, index, [], set()

    def flag(self, node, rule, msg):
        key = (node.lineno, getattr(node, "col_offset", 0), rule)
        if key in self.seen:
            return
        self.seen.add(key)
        self.bad.append(f"{self.rel}:{node.lineno}: [{rule}] {msg}")

    def _check_value(self, node, ctx):
        for n in ast.walk(node):
            if is_click_call(n):
                if has_args(n):
                    self.flag(n, "R-CONSUME", f"{ctx} on raising click() — use try_click")
                else:
                    self.flag(n, "R-ELEMENT",
                              f"{ctx} on WebElement.click() (returns None — always falsy)")

    def visit_If(self, n): self._check_value(n.test, "branch"); self.generic_visit(n)
    def visit_While(self, n): self._check_value(n.test, "loop condition"); self.generic_visit(n)
    def visit_Assert(self, n): self._check_value(n.test, "assert"); self.generic_visit(n)
    def visit_IfExp(self, n): self._check_value(n.test, "ternary condition"); self.generic_visit(n)
    def visit_comprehension(self, n):
        for cond in n.ifs:
            self._check_value(cond, "comprehension condition")
        self.generic_visit(n)

    def visit_Assign(self, n):
        self._check_value(n.value, "bool assignment"); self.generic_visit(n)

    def visit_AnnAssign(self, n):
        if n.value is not None:
            self._check_value(n.value, "bool assignment")
        self.generic_visit(n)

    def visit_NamedExpr(self, n):
        self._check_value(n.value, "walrus"); self.generic_visit(n)

    def visit_AugAssign(self, n):
        self._check_value(n.value, "augmented assignment"); self.generic_visit(n)

    def visit_Expr(self, n):
        v = n.value
        if isinstance(v, ast.Await):
            v = v.value
        if isinstance(v, ast.BoolOp):
            self._check_value(v, "short-circuit")
        if isinstance(v, ast.Call):
            name = None
            if isinstance(v.func, ast.Attribute):
                name = v.func.attr
            elif isinstance(v.func, ast.Name):
                name = v.func.id
            if (name and name in self.index.bool_methods
                    and not best_effort(name) and name != CLICK):
                self.flag(n, "R-IGNORED",
                          f"result of bool method '{name}' ignored — assert or branch on it")
        self.generic_visit(n)

    def visit_FunctionDef(self, n):
        if n.name not in (CLICK, "try_click"):
            # Any function whose tail returns a raising click() is a wrapper
            # its callers will guard as if it returned False; the annotation
            # (or its absence) does not change that.
            for st in own_nodes(n):
                if isinstance(st, ast.Return) and st.value is not None:
                    for c in ast.walk(st.value):
                        if is_click_call(c) and has_args(c):
                            self.flag(st, "R-WRAPPER",
                                      f"wrapper '{n.name}' returns raising click() — "
                                      "tail can raise; return try_click or catch")
        if is_bool_annotation(n.returns) and n.name not in (CLICK, "try_click"):
            returns = [st for st in own_nodes(n) if isinstance(st, ast.Return)]
            all_true = returns and all(
                isinstance(r.value, ast.Constant) and r.value.value is True
                for r in returns
            )
            if all_true:
                for st in own_nodes(n):
                    if isinstance(st, ast.Expr) and is_click_call(st.value) and has_args(st.value):
                        self.flag(st, "R-ALWAYS-TRUE",
                                  f"'{n.name}' always returns True but contains a bare raising "
                                  "click() — callers' bool guards are dead")
        self.generic_visit(n)

    visit_AsyncFunctionDef = visit_FunctionDef


def iter_files():
    for p in sorted(ROOT.rglob("*.py")):
        rel = p.relative_to(ROOT)
        if any(part in SKIP_DIRS for part in rel.parts):
            continue
        if str(rel) in SKIP_REL:
            continue
        yield p, rel


def main():
    bad = []
    index = Indexer()
    trees = {}
    for p, rel in iter_files():
        try:
            tree = ast.parse(p.read_text(encoding="utf-8"), filename=str(p))
        except SyntaxError as e:
            bad.append(f"{rel}: unparseable: {e}")
            continue
        trees[rel] = tree
        index.visit(tree)

    for name, kinds in index.conflicts.items():
        if "bool" in kinds and "other" in kinds and not best_effort(name) and name != CLICK:
            # Same name, conflicting contracts across classes — R-IGNORED keys on
            # the name, so this ambiguity must be surfaced, not guessed away.
            bad.append(f"[R-CONFLICT] method name '{name}' is bool in one class and "
                       f"non-bool in another — unify or rename")

    for rel, tree in trees.items():
        c = Checker(rel, index)
        c.visit(tree)
        bad.extend(c.bad)
        for n in ast.walk(tree):
            hit = (
                (isinstance(n, ast.Attribute) and n.attr == "safe_click")
                or (isinstance(n, ast.Name) and n.id == "safe_click")
                or (isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))
                    and n.name == "safe_click")
                or (isinstance(n, ast.alias)
                    and "safe_click" in (n.name, n.asname))
            )
            if hit:
                bad.append(f"{rel}:{getattr(n, 'lineno', 0)}: safe_click reference (renamed to click)")

    if bad:
        print("click-contract violations:")
        print("\n".join(sorted(bad)))
        return 1
    print("click contract clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
