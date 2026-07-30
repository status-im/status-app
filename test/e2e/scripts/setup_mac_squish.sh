#!/usr/bin/env bash
# One-time macOS setup: fix Squish native library paths and create a project venv.
# Run from anywhere:
#   test/e2e/scripts/setup_mac_squish.sh
#
# After setup, use the venv like on Linux/Windows:
#   cd test/e2e && source .venv/bin/activate && pytest -m critical

set -euo pipefail

SQUISH_DIR="${SQUISH_DIR:-/Applications/Squish_9_2_2}"
E2E_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="${E2E_ROOT}/.venv"
PY="${SQUISH_DIR}/python/Python.framework/Versions/3.10/bin/python3.10-intel64"
ACTIVATE_MARKER='# status-e2e-squish-env'

if [[ ! -x "$PY" ]]; then
  echo "Squish Python not found: $PY" >&2
  echo "Set SQUISH_DIR to your Squish installation." >&2
  exit 1
fi

echo "Squish dir: $SQUISH_DIR"
echo "E2E root:   $E2E_ROOT"

# squishtest_310.so links @rpath/Python.framework but ships without LC_RPATH.
if ! otool -l "${SQUISH_DIR}/lib/squishtest_310.so" 2>/dev/null | grep -q "${SQUISH_DIR}/python"; then
  echo "Adding rpath to squishtest_310.so ..."
  install_name_tool -add_rpath "${SQUISH_DIR}/python" "${SQUISH_DIR}/lib/squishtest_310.so"
  install_name_tool -add_rpath "${SQUISH_DIR}/python" "${SQUISH_DIR}/lib/libsquishpython_310.dylib"
else
  echo "Squish rpath already configured."
fi

if [[ ! -d "$VENV" ]]; then
  echo "Creating venv at $VENV from Squish Python ..."
  arch -x86_64 "$PY" -m venv "$VENV"
else
  echo "Venv already exists at $VENV"
fi

if ! grep -q "$ACTIVATE_MARKER" "${VENV}/bin/activate"; then
  echo "Configuring venv activate hook for Squish ..."
  cat >> "${VENV}/bin/activate" <<EOF

$ACTIVATE_MARKER
export SQUISH_DIR="\${SQUISH_DIR:-${SQUISH_DIR}}"
export PYTHONPATH="\${SQUISH_DIR}/lib:\${SQUISH_DIR}/lib/python"
EOF
else
  echo "Venv activate hook already configured."
fi

echo "Installing dependencies ..."
arch -x86_64 "${VENV}/bin/python" -m pip install --upgrade pip
arch -x86_64 "${VENV}/bin/python" -m pip install -r "${E2E_ROOT}/requirements.txt"

echo "Verifying imports ..."
export SQUISH_DIR
export PYTHONPATH="${SQUISH_DIR}/lib:${SQUISH_DIR}/lib/python"
arch -x86_64 "${VENV}/bin/python" -c "import squishtest; import cryptography; print('OK:', cryptography.__version__)"

echo ""
echo "Done. Next:"
echo "  cd test/e2e"
echo "  source .venv/bin/activate"
echo "  pytest -m critical --maxfail=1"
