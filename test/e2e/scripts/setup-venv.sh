#!/bin/sh
# Create test/e2e/.venv with a Python of the same architecture as the app.
# On Apple Silicon an x86_64 interpreter (Squish 9.3 ships one) makes the
# universal QtWebEngineProcess start as x86_64, and the in-app browser's
# renderer dies on the first message from the arm64 app.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"

arm_host=0
if command -v sysctl >/dev/null 2>&1; then
    if [ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" = 1 ]; then
        arm_host=1
    fi
fi

# The venv being replaced is often first on PATH.
PATH=$(printf '%s' "$PATH" | tr ':' '\n' | grep -v "^$root/.venv/bin$" | paste -sd: -)

machine() {
    "$1" -c 'import platform; print(platform.machine())' 2>/dev/null || true
}

inside_venv() {
    case "$1" in
        "$root/.venv/"*) return 0 ;;
    esac
    return 1
}

# pytest reads INSPECTOR_PLUGINS from the process environment and does not load .env.
# A .pth line runs for every start of this interpreter, including PyCharm.
# sitecustomize.py does not: the base Python already has one earlier on sys.path.
install_inspector_plugins() {
    .venv/bin/python - "$1" <<'PY'
import pathlib, sys
plugins = sys.argv[1]
root = pathlib.Path(".venv")
site = next(path for path in (root / "lib").glob("python*/site-packages"))
(site / "sitecustomize.py").unlink(missing_ok=True)
(site / "inspector-plugins.pth").write_text(
    "import os; os.environ.setdefault('INSPECTOR_PLUGINS', " + repr(plugins) + ")\n"
)
marker = "# INSPECTOR_PLUGINS from setup-venv.sh"
line = "export INSPECTOR_PLUGINS=" + repr(plugins)
activate = root / "bin" / "activate"
text = activate.read_text()
block = "\n" + marker + "\n" + line + "\n"
if marker in text:
    head, _, _tail = text.partition(marker)
    text = head.rstrip() + block
else:
    text = text.rstrip() + block
activate.write_text(text + "\n")
PY
}

py=''
prefix=''
for candidate in \
    "$(command -v python3 2>/dev/null || true)" \
    /opt/homebrew/bin/python3 \
    /opt/homebrew/bin/python3.14 \
    /opt/homebrew/bin/python3.12 \
    /opt/homebrew/bin/python3.10 \
    /usr/bin/python3
do
    [ -n "$candidate" ] && [ -x "$candidate" ] || continue
    inside_venv "$candidate" && continue
    arch=$(machine "$candidate")
    launch=''
    if [ "$arm_host" = 1 ] && [ "$arch" != arm64 ]; then
        if [ "$(/usr/bin/arch -arm64 "$candidate" -c 'import platform; print(platform.machine())' 2>/dev/null || true)" = arm64 ]; then
            launch='/usr/bin/arch -arm64'
            arch=arm64
        else
            echo "setup-venv: skip $candidate ($arch only)" >&2
            continue
        fi
    fi
    py=$candidate
    prefix=$launch
    break
done

if [ -z "$py" ]; then
    echo "setup-venv: no native Python found. On Apple Silicon install one with Homebrew, not Squish's." >&2
    exit 1
fi

plugins="${1:-${INSPECTOR_PLUGINS:-}}"
if [ -z "$plugins" ]; then
    for candidate in \
        "$HOME/.cache/status-e2e-qt/qmlinspector-macos-6.11.0/plugins" \
        "$HOME/.cache/status-e2e-qt/qmlinspector-macos/plugins" \
        /tmp/qmlinspector/plugins
    do
        if [ -e "$candidate/generic/libqmlinspector.dylib" ] || [ -e "$candidate/generic/libqmlinspector.so" ]; then
            plugins=$candidate
            break
        fi
    done
fi
plugins="${plugins:-/tmp/qmlinspector/plugins}"

echo "setup-venv: $prefix $py ($arch)"
rm -rf .venv
# shellcheck disable=SC2086
$prefix "$py" -m venv .venv
.venv/bin/python -m pip install --upgrade pip
.venv/bin/python -m pip install -r requirements.txt
install_inspector_plugins "$plugins"

got=$(machine .venv/bin/python)
if [ "$arm_host" = 1 ] && [ "$got" != arm64 ]; then
    echo "setup-venv: .venv/bin/python is $got, want arm64" >&2
    exit 1
fi
echo "setup-venv: .venv/bin/python is $($root/.venv/bin/python -c 'import sys; print(sys.version.split()[0])') $got"
echo "setup-venv: INSPECTOR_PLUGINS=$plugins"
