#!/bin/bash
# Builds the inspector plugin on a CI runner of any of the three systems.
# usage: plugin.sh <output directory>
# Result: <output directory>/plugins/generic/
set -euo pipefail

inspector=$(CDPATH= cd -- "$(dirname "$0")/../inspector" && pwd)
case "$(uname -s)" in
    Linux) "$inspector/build-plugin.sh" "$1" ;;
    Darwin) "$inspector/build-plugin-macos.sh" "$1" ;;
    *)
        SETUP_PYTHON=python pwsh -NoProfile -File "$(cygpath -w "$inspector/build-plugin-windows.ps1")" "$(cygpath -w "$1")"
        ;;
esac
