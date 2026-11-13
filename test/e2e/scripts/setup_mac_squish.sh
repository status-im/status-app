#!/usr/bin/env bash
# One-time macOS setup for Squish 9.3.
# Squish 9.3 bundles Python 3.14 only. squishtest_*.so is x86_64, so this
# builds an x86_64 venv from python3.14-intel64, relinks it to Squish's
# Python.framework, and adds rpath so squishtest_314.so loads.
#
#   test/e2e/scripts/setup_mac_squish.sh
#   cd test/e2e && source .venv/bin/activate && pytest -m critical
#
# Do not use the arm64 slice of python3.14 or Homebrew python@3.10 as the
# venv base — squishtest will fail with "incompatible architecture".

set -euo pipefail

SQUISH_DIR="${SQUISH_DIR:-/Applications/Squish_9_3_0}"
E2E_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="${E2E_ROOT}/.venv"
PY="${PYTHON:-${SQUISH_DIR}/python/Python.framework/Versions/3.14/bin/python3.14}"
INTEL64="${SQUISH_DIR}/python/Python.framework/Versions/3.14/bin/python3.14-intel64"
SQUISH_PYTHON_LIB="${SQUISH_DIR}/python/Python.framework/Versions/3.14/Python"
SQUISHTEST_SO="${SQUISH_DIR}/lib/squishtest_314.so"
SQUISHPYTHON_DYLIB="${SQUISH_DIR}/lib/libsquishpython_314.dylib"
OPENSSL_PREFIX="${OPENSSL_PREFIX:-/usr/local/opt/openssl@3}"
ACTIVATE_MARKER='# status-e2e-squish-env'

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

venv_is_x86_64_314() {
  [[ -x "${VENV}/bin/python" ]] || return 1
  local ver machine
  ver="$("${VENV}/bin/python" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null || true)"
  machine="$("${VENV}/bin/python" -c 'import platform; print(platform.machine())' 2>/dev/null || true)"
  [[ "$ver" == "3.14" && "$machine" == "x86_64" ]]
}

ensure_venv_x86_64_squish_python() {
  local dest="${VENV}/bin/python3.14-x86_64"
  [[ -x "$INTEL64" ]] || fail "Squish python3.14-intel64 not found: $INTEL64"
  echo "Installing x86_64 venv interpreter linked to Squish Python.framework ..."
  cp "$INTEL64" "$dest"
  # intel64 uses @loader_path/../Python (correct inside Squish, wrong in .venv/bin).
  install_name_tool -change \
    '@loader_path/../Python' \
    "$SQUISH_PYTHON_LIB" \
    "$dest"
  install_name_tool -change \
    /Library/Frameworks/Python.framework/Versions/3.14/Python \
    "$SQUISH_PYTHON_LIB" \
    "$dest" 2>/dev/null || true
  codesign --force --sign - "$dest" >/dev/null
  chmod +x "$dest"
  ln -sf python3.14-x86_64 "${VENV}/bin/python"
  ln -sf python3.14-x86_64 "${VENV}/bin/python3"
  ln -sf python3.14-x86_64 "${VENV}/bin/python3.14"
}

has_rpath() {
  otool -l "$1" 2>/dev/null | awk '/LC_RPATH/,/path /' | grep -F "path $2" >/dev/null
}

ensure_squishtest_rpath() {
  local lib
  for lib in "$SQUISHTEST_SO" "$SQUISHPYTHON_DYLIB"; do
    [[ -f "$lib" ]] || continue
    if ! has_rpath "$lib" "${SQUISH_DIR}/python"; then
      echo "Adding Python rpath to $(basename "$lib") ..."
      install_name_tool -add_rpath "${SQUISH_DIR}/python" "$lib"
    fi
    if ! has_rpath "$lib" "${SQUISH_DIR}/lib"; then
      echo "Adding lib rpath to $(basename "$lib") ..."
      install_name_tool -add_rpath "${SQUISH_DIR}/lib" "$lib"
    fi
    codesign --force --sign - "$lib" >/dev/null 2>&1 || true
  done
}

write_env_file() {
  local env_file="${E2E_ROOT}/.env"
  if [[ ! -f "$env_file" && -f "${E2E_ROOT}/.env.example" ]]; then
    cp "${E2E_ROOT}/.env.example" "$env_file"
    echo "Created .env for PyCharm (SQUISH_DIR / PYTHONPATH)"
  fi
  if [[ -f "$env_file" ]]; then
    if grep -q '^SQUISH_DIR=' "$env_file"; then
      sed -i.bak "s|^SQUISH_DIR=.*|SQUISH_DIR=${SQUISH_DIR}|" "$env_file"
    else
      echo "SQUISH_DIR=${SQUISH_DIR}" >> "$env_file"
    fi
    if grep -q '^PYTHONPATH=' "$env_file"; then
      sed -i.bak "s|^PYTHONPATH=.*|PYTHONPATH=${SQUISH_DIR}/lib:${SQUISH_DIR}/lib/python|" "$env_file"
    else
      echo "PYTHONPATH=${SQUISH_DIR}/lib:${SQUISH_DIR}/lib/python" >> "$env_file"
    fi
    rm -f "${env_file}.bak"
  fi
}

print_qt_hint() {
  local ini="${SQUISH_DIR}/etc/squish.ini"
  local current=""
  if [[ -f "$ini" ]]; then
    current="$(sed -n 's/^UserQtLibDirectory *= *"\(.*\)"/\1/p' "$ini" | head -1)"
  fi
  echo ""
  echo "Squish Qt (UserQtLibDirectory): ${current:-not set}"
  echo "This must be the same Qt patch the Status.app was built with"
  echo "(CI nightly is Qt 6.11.0 — not Homebrew qtbase 6.11.1)."
  echo "Configure it once with: ${SQUISH_DIR}/bin/squishconfig --qt=/path/to/QtCore.framework"
}

# --- preflight ---

[[ "$(uname -s)" == Darwin ]] || fail "This script is for macOS only."

if ! arch -x86_64 /usr/bin/true 2>/dev/null; then
  fail "Rosetta 2 is required (squishtest_314.so is x86_64).
Install it:
  softwareupdate --install-rosetta --agree-to-license"
fi

[[ -x "$PY" ]] || fail "Squish Python 3.14 not found: $PY
Set SQUISH_DIR to Squish 9.3 (default: /Applications/Squish_9_3_0)."

[[ -x "$INTEL64" ]] || fail "Squish python3.14-intel64 not found: $INTEL64"

[[ -f "$SQUISHTEST_SO" ]] || fail "squishtest_314.so not found: $SQUISHTEST_SO"

[[ -f "$SQUISH_PYTHON_LIB" ]] || fail "Squish Python.framework not found: $SQUISH_PYTHON_LIB"

echo "Squish dir: $SQUISH_DIR"
echo "E2E root:   $E2E_ROOT"
echo "Python:     $PY"
echo "intel64:    $INTEL64"

ensure_squishtest_rpath

if [[ -d "$VENV" ]] && ! venv_is_x86_64_314; then
  echo "Existing .venv is not Squish 3.14 x86_64; recreating ..."
  rm -rf "$VENV"
fi

if [[ ! -d "$VENV" ]]; then
  echo "Creating venv at $VENV from Squish Python 3.14 (x86_64) ..."
  arch -x86_64 "$PY" -m venv "$VENV"
  ensure_venv_x86_64_squish_python
else
  echo "Venv already exists at $VENV"
  if [[ ! -x "${VENV}/bin/python3.14-x86_64" ]] || ! venv_is_x86_64_314; then
    ensure_venv_x86_64_squish_python
  fi
fi

echo "Venv Python:"
"${VENV}/bin/python" -c "import sys, platform; print(sys.version); print('machine:', platform.machine()); print('base_prefix:', sys.base_prefix)"
[[ "$("${VENV}/bin/python" -c 'import platform; print(platform.machine())')" == x86_64 ]] \
  || fail "venv python is not x86_64 — squishtest will not load"

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

write_env_file

if [[ -d "$OPENSSL_PREFIX/lib" && -d "$OPENSSL_PREFIX/include" ]]; then
  export LDFLAGS="-L${OPENSSL_PREFIX}/lib ${LDFLAGS:-}"
  export CPPFLAGS="-I${OPENSSL_PREFIX}/include ${CPPFLAGS:-}"
  export PKG_CONFIG_PATH="${OPENSSL_PREFIX}/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
  echo "Using OpenSSL at $OPENSSL_PREFIX"
else
  echo "WARNING: Intel OpenSSL not found at $OPENSSL_PREFIX (scrypt may fail to build)."
  echo "  arch -x86_64 /usr/local/bin/brew install openssl@3"
fi

echo "Installing dependencies ..."
"${VENV}/bin/python" -m pip install --upgrade pip
"${VENV}/bin/python" -m pip install -r "${E2E_ROOT}/requirements.txt"

# On Apple Silicon, pip builds ckzg as a universal2 wheel whose x86_64 slice
# leaves blst symbols undefined. Squish Python is x86_64, so rebuild that slice.
if [[ "$(uname -m)" == "arm64" ]]; then
  CKZG_VERSION="$("${VENV}/bin/python" -c 'import importlib.metadata as m; print(m.version("ckzg"))')"
  echo "Rebuilding ckzg ${CKZG_VERSION} for x86_64 ..."
  ARCHFLAGS="-arch x86_64" CFLAGS="-arch x86_64" LDFLAGS="-arch x86_64" \
    "${VENV}/bin/python" -m pip install --force-reinstall --no-binary=ckzg "ckzg==${CKZG_VERSION}"
fi

echo "Verifying imports ..."
export SQUISH_DIR
export PYTHONPATH="${SQUISH_DIR}/lib:${SQUISH_DIR}/lib/python"
"${VENV}/bin/python" -c "import squishtest, cryptography, numpy, cv2, ckzg, platform, sys; print('OK squishtest + cryptography', cryptography.__version__, '+ numpy', numpy.__version__, '+ cv2', cv2.__version__, '+ ckzg', 'on', platform.machine(), sys.version.split()[0])"

print_qt_hint

echo ""
echo "Done. Next:"
echo "  1. Set AUT_PATH in configs/_local.py (e.g. ~/Downloads/Status.app)"
echo "  2. cd test/e2e && source .venv/bin/activate"
echo "  3. pytest tests/onboarding/test_language_selector_and_password_strength.py -v --maxfail=1"
echo "PyCharm: existing interpreter test/e2e/.venv/bin/python (3.14 x86_64), working dir test/e2e"
echo "  Put SQUISH_DIR and PYTHONPATH on the pytest run configuration, not the interpreter."
echo "  Remove any leftover 3.10 / arm64 interpreter first (Show All → −)."
