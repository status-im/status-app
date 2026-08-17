#!/usr/bin/env python3
"""Click-contract checker (AST-based).

click() raises on failure and only ever returns True; try_click() is the
bool-returning, never-raising variant. Branching, asserting, looping, or
assigning on click()'s result is therefore dead code — as is a bool-annotated
wrapper whose tail is 'return x.click(...)' (True-or-raise leaks to callers).
Zero-argument .click() is WebElement.click(), which returns None: branching on
it is always-False and equally flagged. Runs at pytest collection via
conftest; standalone: python3 scripts/check_click_contract.py [root].
Known limits: bare raising clicks inside bool functions and dynamic dispatch
are not detected."""
import ast, pathlib, sys

CLICK_NAMES = {"click"}  # the page helper; safe_click is banned outright below
SKIP_DIRS = {".venv", "venv", "env", "__pycache__", "node_modules", ".git"}

def is_helper_click(node):
    """Call of X.click(...)/X.safe_click(...) WITH args = page helper (raises).
    Zero-arg .click() = WebElement — branching on that is a different, also-flagged bug."""
    return (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
            and node.func.attr in CLICK_NAMES)

def helper_has_args(node):
    return bool(node.args or node.keywords)

class V(ast.NodeVisitor):
    def __init__(self, path):
        self.path, self.bad = path, []
    def flag(self, node, msg):
        self.bad.append(f"{self.path}:{node.lineno}: {msg}")
    def check_expr_tree(self, test, ctx):
        for n in ast.walk(test):
            if is_helper_click(n):
                if helper_has_args(n):
                    self.flag(n, f"{ctx} on raising {n.func.attr}() — use try_click")
                else:
                    self.flag(n, f"{ctx} on WebElement.click() (returns None — always falsy)")
    def visit_If(self, n): self.check_expr_tree(n.test, "branch"); self.generic_visit(n)
    def visit_While(self, n): self.check_expr_tree(n.test, "loop condition"); self.generic_visit(n)
    def visit_Assert(self, n): self.check_expr_tree(n.test, "assert"); self.generic_visit(n)
    def visit_Assign(self, n):
        if is_helper_click(n.value) and helper_has_args(n.value):
            self.flag(n, f"bool assignment of raising {n.value.func.attr}() — use try_click")
        self.generic_visit(n)
    def visit_NamedExpr(self, n):
        if is_helper_click(n.value) and helper_has_args(n.value):
            self.flag(n, "walrus on raising click() — use try_click")
        self.generic_visit(n)
    def visit_UnaryOp(self, n):
        if isinstance(n.op, ast.Not) and is_helper_click(n.operand):
            self.flag(n, "negation of raising click() — use try_click")
        self.generic_visit(n)
    def visit_FunctionDef(self, n):
        ret = n.returns
        is_bool = (isinstance(ret, ast.Name) and ret.id == "bool")
        if is_bool and n.name not in ("safe_click", "click", "try_click"):
            for stmt in ast.walk(n):
                if isinstance(stmt, ast.Return) and stmt.value is not None \
                   and is_helper_click(stmt.value) and helper_has_args(stmt.value):
                    self.flag(stmt, f"bool-annotated wrapper '{n.name}' returns raising "
                                    f"{stmt.value.func.attr}() — tail can raise, callers' "
                                    f"bool guards are dead; return try_click or catch")
        self.generic_visit(n)
    visit_AsyncFunctionDef = visit_FunctionDef

def main(root):
    root = pathlib.Path(root)
    bad = []
    for p in sorted(root.rglob("*.py")):
        if any(part in SKIP_DIRS for part in p.parts): continue
        if p.name in ("base_page.py",): continue
        try:
            tree = ast.parse(p.read_text(encoding="utf-8"), filename=str(p))
        except SyntaxError as e:
            bad.append(f"{p}: unparseable: {e}"); continue
        v = V(p.relative_to(root)); v.visit(tree); bad += v.bad
        for n in ast.walk(tree):  # safe_click token ban (post-rename only meaningful)
            if isinstance(n, ast.Attribute) and n.attr == "safe_click":
                bad.append(f"{p}:{n.lineno}: safe_click reference (renamed to click)")
    if bad:
        print("click-contract violations:"); print("\n".join(bad)); return 1
    print("click contract clean"); return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "."))
