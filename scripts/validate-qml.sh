#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
ROOT_DIR=$(realpath "$SCRIPT_DIR/..")

QT_QML_PATH="${QT_QML_PATH:-${QTDIR}/qml}"

QMLLINT="${QTDIR}/bin/qmllint"
[[ ! -x "$QMLLINT" ]] && QMLLINT="${QTDIR}/libexec/qmllint"

if [[ ! -x "$QMLLINT" ]]; then
    echo "Error: qmllint not found. Set QTDIR to your Qt installation path."
    exit 1
fi

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed."
    exit 1
fi

echo "qmllint: $QMLLINT"
echo "Qt modules: $QT_QML_PATH"
echo ""

# Collect all QML files
mapfile -d '' QML_FILES < <(find "$ROOT_DIR/ui" -name "*.qml" -print0)
echo "Checking ${#QML_FILES[@]} files..."

# Run qmllint with JSON output for precise filtering
JSON_OUTPUT=$("$QMLLINT" \
    --json - \
    -I "$ROOT_DIR/ui" \
    -I "$ROOT_DIR/ui/imports" \
    -I "$ROOT_DIR/ui/app" \
    -I "$ROOT_DIR/ui/StatusQ/src" \
    -I "$QT_QML_PATH" \
    "${QML_FILES[@]}" 2>/dev/null) || true

# Filter JSON for real errors only:
# 1. "Failed to import Qt*" - Missing Qt modules (runtime crash)
# 2. "duplicated-name" warnings - Duplicate symbols (runtime crash)
#
# Excluded (not errors):
# - QtWebEngine/QtWebChannel - disabled on mobile intentionally
# - QtModelsToolkit - third-party C++ plugin
# - qmldir missing files, cascading errors, etc.
ERRORS=$(echo "$JSON_OUTPUT" | jq -r '
  .files[]
  | .filename as $file
  | .warnings[]
  | select(
      (.id == "duplicated-name") or
      ((.id == "import") and (.message | test("Failed to import Qt(?!(ModelsToolkit|WebEngine|WebChannel))")))
    )
  | "\($file):\(.line):\(.column): \(.message)"
' 2>/dev/null || true)

if [[ -n "$ERRORS" ]]; then
    echo ""
    echo "ERRORS:"
    echo "$ERRORS"
    echo ""
    ERROR_COUNT=$(echo "$ERRORS" | wc -l | tr -d ' ')
    echo "Total: $ERROR_COUNT"
    exit 1
fi

echo "OK"
exit 0
