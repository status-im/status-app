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
# Universal interpreter with @loader_path → Squish's Python.framework.
# Do not use python3.10-intel64 as the venv base: it loads python.org
# /Library/Frameworks, then squishtest loads Squish's framework → segfault.
PY="${SQUISH_DIR}/python/Python.framework/Versions/3.10/bin/python3.10"
INTEL64="${SQUISH_DIR}/python/Python.framework/Versions/3.10/bin/python3.10-intel64"
SQUISH_PYTHON_LIB="${SQUISH_DIR}/python/Python.framework/Versions/3.10/Python"
OPENSSL_PREFIX="/usr/local/opt/openssl@3"
ACTIVATE_MARKER='# status-e2e-squish-env'

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

venv_uses_python_org_framework() {
  [[ -x "${VENV}/bin/python" ]] && otool -L "${VENV}/bin/python" 2>/dev/null | grep -q '/Library/Frameworks/Python.framework'
}

ensure_venv_x86_64_squish_python() {
  local dest="${VENV}/bin/python3.10-x86_64"
  [[ -x "$INTEL64" ]] || fail "Squish python3.10-intel64 not found: $INTEL64"
  echo "Installing x86_64 venv interpreter linked to Squish Python.framework ..."
  cp "$INTEL64" "$dest"
  install_name_tool -change \
    /Library/Frameworks/Python.framework/Versions/3.10/Python \
    "$SQUISH_PYTHON_LIB" \
    "$dest"
  codesign --force --sign - "$dest" >/dev/null
  chmod +x "$dest"
  ln -sf python3.10-x86_64 "${VENV}/bin/python"
  ln -sf python3.10-x86_64 "${VENV}/bin/python3"
  ln -sf python3.10-x86_64 "${VENV}/bin/python3.10"
}

print_qt_hint() {
  local ini="${SQUISH_DIR}/etc/squish.ini"
  local current=""
  if [[ -f "$ini" ]]; then
    current="$(sed -n 's/^UserQtLibDirectory *= *"\(.*\)"/\1/p' "$ini" | head -1)"
  fi
  echo ""
  echo "Squish Qt (UserQtLibDirectory): ${current:-not set}"
  echo "This must be the same Qt patch the Status.app was built with."
  echo "Configure it once with: ${SQUISH_DIR}/bin/squishconfig --qt=/path/to/QtCore.framework"
}

# --- preflight ---

[[ "$(uname -s)" == Darwin ]] || fail "This script is for macOS only."

if [[ ! -x "$PY" ]]; then
  fail "Squish Python not found: $PY
Set SQUISH_DIR to your Squish installation (default: /Applications/Squish_9_2_2)."
fi

if ! arch -x86_64 /usr/bin/true 2>/dev/null; then
  fail "Rosetta 2 is required (Squish Python is x86_64).
Install it:
  softwareupdate --install-rosetta --agree-to-license"
fi

if [[ ! -d "$OPENSSL_PREFIX/lib" || ! -d "$OPENSSL_PREFIX/include" ]]; then
  fail "x86_64 OpenSSL not found at $OPENSSL_PREFIX
scrypt (via zpywallet) must be compiled against Intel OpenSSL, not /opt/homebrew.

If Intel Homebrew is not installed:
  arch -x86_64 /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"
Then:
  arch -x86_64 /usr/local/bin/brew install openssl@3
Always prefix Intel brew with: arch -x86_64 /usr/local/bin/brew"
fi

echo "Squish dir: $SQUISH_DIR"
echo "E2E root:   $E2E_ROOT"
echo "OpenSSL:    $OPENSSL_PREFIX"

# squishtest_310.so links @rpath/Python.framework but ships without LC_RPATH.
if ! otool -l "${SQUISH_DIR}/lib/squishtest_310.so" 2>/dev/null | grep -q "${SQUISH_DIR}/python"; then
  echo "Adding rpath to squishtest_310.so ..."
  install_name_tool -add_rpath "${SQUISH_DIR}/python" "${SQUISH_DIR}/lib/squishtest_310.so"
  install_name_tool -add_rpath "${SQUISH_DIR}/python" "${SQUISH_DIR}/lib/libsquishpython_310.dylib"
else
  echo "Squish rpath already configured."
fi

# _hashlib.so is linked to python.org libssl.1.1; Squish already ships it beside Python.
HASHLIB_SO="${SQUISH_DIR}/python/Python.framework/Versions/3.10/lib/python3.10/lib-dynload/_hashlib.cpython-310-darwin.so"
PYORG_SSL_LIB="/Library/Frameworks/Python.framework/Versions/3.10/lib"
if [[ -f "$HASHLIB_SO" ]] && otool -L "$HASHLIB_SO" | grep -q "$PYORG_SSL_LIB/libssl.1.1.dylib"; then
  echo "Repointing _hashlib.so to Squish OpenSSL 1.1 ..."
  install_name_tool -change "$PYORG_SSL_LIB/libssl.1.1.dylib" "@loader_path/../../libssl.1.1.dylib" "$HASHLIB_SO"
  install_name_tool -change "$PYORG_SSL_LIB/libcrypto.1.1.dylib" "@loader_path/../../libcrypto.1.1.dylib" "$HASHLIB_SO"
  codesign --force --sign - "$HASHLIB_SO" >/dev/null
fi

if [[ -d "$VENV" ]] && venv_uses_python_org_framework; then
  echo "Venv loads python.org Python.framework; recreating from Squish Python ..."
  rm -rf "$VENV"
fi

if [[ ! -d "$VENV" ]]; then
  echo "Creating venv at $VENV from Squish Python ..."
  arch -x86_64 "$PY" -m venv "$VENV"
  ensure_venv_x86_64_squish_python
else
  echo "Venv already exists at $VENV"
  if [[ ! -x "${VENV}/bin/python3.10-x86_64" ]] || venv_uses_python_org_framework; then
    ensure_venv_x86_64_squish_python
  fi
fi

echo "Venv Python:"
arch -x86_64 "${VENV}/bin/python" -c "import sys; print(sys.version); print('base_prefix:', sys.base_prefix)"

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

if [[ ! -f "${E2E_ROOT}/configs/_local.py" ]]; then
  cp "${E2E_ROOT}/configs/_local.default.py" "${E2E_ROOT}/configs/_local.py"
  echo "Created configs/_local.py — set AUT_PATH to your Status.app"
fi

if [[ ! -f "${E2E_ROOT}/.env" && -f "${E2E_ROOT}/.env.example" ]]; then
  cp "${E2E_ROOT}/.env.example" "${E2E_ROOT}/.env"
  echo "Created .env for PyCharm (SQUISH_DIR / PYTHONPATH)"
fi

export LDFLAGS="-L${OPENSSL_PREFIX}/lib ${LDFLAGS:-}"
export CPPFLAGS="-I${OPENSSL_PREFIX}/include ${CPPFLAGS:-}"
export PKG_CONFIG_PATH="${OPENSSL_PREFIX}/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
echo "Using OpenSSL at $OPENSSL_PREFIX"

echo "Installing dependencies ..."
arch -x86_64 "${VENV}/bin/python" -m pip install --upgrade pip
arch -x86_64 "${VENV}/bin/python" -m pip install -r "${E2E_ROOT}/requirements.txt"

echo "Verifying imports ..."
export SQUISH_DIR
export PYTHONPATH="${SQUISH_DIR}/lib:${SQUISH_DIR}/lib/python"
arch -x86_64 "${VENV}/bin/python" -c "import squishtest; import cryptography; print('OK:', cryptography.__version__)"

print_qt_hint

echo ""
echo "Done. Next:"
echo "  1. Set AUT_PATH in configs/_local.py (e.g. ~/Downloads/Status.app)"
echo "  2. cd test/e2e && source .venv/bin/activate"
echo "  3. pytest tests/onboarding/test_language_selector_and_password_strength.py -v --maxfail=1"
echo "PyCharm: existing interpreter test/e2e/.venv/bin/python, working dir test/e2e, use .env"
