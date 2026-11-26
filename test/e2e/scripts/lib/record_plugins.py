import os
import pathlib
import sys

plugins = sys.argv[1]
root = pathlib.Path(".venv")
if os.name == "nt":
    sites = [root / "Lib" / "site-packages"]
    activates = [root / "Scripts" / "Activate.ps1"]
    e2e_env_line = (
        "$e2eRoot = Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent\n"
        "$dotenv = Join-Path $e2eRoot '.env'\n"
        "if (Test-Path $dotenv) {\n"
        "  Get-Content $dotenv | ForEach-Object {\n"
        "    if ($_ -match '^\\s*#' -or $_ -notmatch '=') { return }\n"
        "    $n, $v = $_ -split '=', 2\n"
        "    $n = $n.Trim(); $v = $v.Trim().Trim('\"').Trim(\"'\")\n"
        "    if (-not [Environment]::GetEnvironmentVariable($n)) { Set-Item -Path \"env:$n\" -Value $v }\n"
        "  }\n"
        "}\n"
    )
else:
    sites = list((root / "lib").glob("python*/site-packages"))
    activates = [root / "bin" / "activate"]
    e2e_env_line = (
        'e2e_root="$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"\n'
        'if [ -f "$e2e_root/.env" ]; then set -a; . "$e2e_root/.env"; set +a; fi\n'
    )

_e2e_env_pth = """\
import os, pathlib
_root = pathlib.Path(__file__).resolve().parents[3]
_env = _root / '.env'
if _env.is_file():
    for _line in _env.read_text(encoding='utf-8').splitlines():
        _line = _line.strip()
        if not _line or _line.startswith('#') or '=' not in _line:
            continue
        _k, _, _v = _line.partition('=')
        _v = _v.strip().strip('"').strip("'")
        os.environ.setdefault(_k.strip(), _v)
"""

marker_plugins = "# INSPECTOR_PLUGINS from setup"
marker_env = "# E2E .env from setup"

for site in sites:
    site.mkdir(parents=True, exist_ok=True)
    (site / "inspector-plugins.pth").write_text(
        "import os; os.environ.setdefault('INSPECTOR_PLUGINS', " + repr(plugins) + ")\n",
        encoding="utf-8",
    )
    (site / "e2e-env.pth").write_text(_e2e_env_pth, encoding="utf-8")

for activate in activates:
    if not activate.is_file():
        continue
    text = activate.read_text(encoding="utf-8-sig")
    line_plugins = (
        '$env:INSPECTOR_PLUGINS = ' + repr(plugins)
        if activate.suffix == ".ps1"
        else "export INSPECTOR_PLUGINS=" + repr(plugins)
    )
    for marker, block in (
        (marker_plugins, f"\n{marker_plugins}\n{line_plugins}\n"),
        (marker_env, f"\n{marker_env}\n{e2e_env_line}"),
    ):
        if marker in text:
            head, _, _ = text.partition(marker)
            text = head.rstrip() + block
        else:
            text = text.rstrip() + block
    activate.write_text(text + "\n", encoding="utf-8")