#!/bin/bash
set -euo pipefail

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
SETUP_ROOT=$(CDPATH= cd -- "$here/.." && pwd)
# shellcheck source=setup-common.sh
. "$here/setup-common.sh"
# shellcheck source=ensure-dotenv.sh
. "$here/ensure-dotenv.sh"
# shellcheck source=start-waku-fleet.sh
. "$here/start-waku-fleet.sh"
cd "$SETUP_ROOT"

platform=${SETUP_PLATFORM:?}

case "$platform" in
    macos)
        [ "$(uname)" = Darwin ] || {
            echo "setup: this script is for macOS." >&2
            exit 1
        }
        arm_host || {
            echo "setup: this script is for Apple Silicon." >&2
            exit 1
        }
        xcode-select -p >/dev/null 2>&1 || {
            echo "setup: install Xcode Command Line Tools: xcode-select --install" >&2
            exit 1
        }
        command -v cmake >/dev/null 2>&1 || {
            echo "setup: install CMake: brew install cmake" >&2
            exit 1
        }
        ;;
    linux)
        [ "$(uname)" = Linux ] || {
            echo "setup: this script is for Linux." >&2
            exit 1
        }
        command -v docker >/dev/null 2>&1 || {
            echo "setup: install Docker" >&2
            exit 1
        }
        docker info >/dev/null 2>&1 || {
            echo "setup: start Docker" >&2
            exit 1
        }
        ;;
    *)
        echo "setup: unknown SETUP_PLATFORM=$platform" >&2
        exit 1
        ;;
esac

command -v git >/dev/null 2>&1 || {
    echo "setup: install git" >&2
    exit 1
}

py=$(ensure_python)
case "$platform" in
    macos)
        out=${SETUP_PLUGIN_OUT:-$HOME/.cache/status-e2e-qt/qmlinspector-macos}
        "$here/../inspector/build-plugin-macos.sh" "$out"
        ;;
    linux)
        out=${SETUP_PLUGIN_OUT:-/tmp/qmlinspector}
        "$here/../inspector/build-plugin.sh" "$out"
        ;;
esac

ensure_dotenv
plugins=${1:-$out/plugins}
create_venv "$py" "$plugins"
if [ -f .env ]; then set -a; # shellcheck disable=SC1091
. ./.env; set +a; fi
start_waku_fleet "$SETUP_ROOT/.venv/bin/python"
echo "setup: activate with: source .venv/bin/activate"
echo "setup: INSPECTOR_PLUGINS=$plugins"