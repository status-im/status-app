#!/bin/bash
# Runs inside the image, started by ../run.sh. The environment follows ci/Jenkinsfile.tests-e2e,
# with the stand-in where that file points at Squish.
set -euo pipefail
stand_in=/work/test/e2e_squish_stand_in

# Short paths: the keyring's socket path must fit in a Unix socket address.
export HOME=/tmp/home XDG_CONFIG_HOME=/tmp/home/config WORKSPACE_TMP=/tmp/workspace
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$WORKSPACE_TMP"

if [ ! -x /state/venv/bin/python ]; then
  python3 -m venv /state/venv
  /state/venv/bin/pip install --quiet -r /work/test/e2e/requirements.txt
fi
export PATH=/state/venv/bin:$PATH

# The container shares the host's network namespace, and with it the abstract socket an
# X server would open. "-nolisten local" keeps this display off it.
Xvfb :99 -screen 0 2560x1440x24 -dpi 1 -nolisten tcp -nolisten local > /tmp/xvfb.log 2>&1 &
export DISPLAY=:99
sleep 1
fluxbox > /tmp/fluxbox.log 2>&1 &

cd /work/test/e2e
[ -e configs/_local.py ] || cp configs/_local.ci.py configs/_local.py

export STATUS_RUNTIME_HTTP_API=False STATUS_RUNTIME_WS_API=False
export QML_DISABLE_CACHE=1 QT_QPA_PLATFORM=linuxfb QT_LOGGING_RULES='*.warning=true'
export STATUS_RUNTIME_TEST_MODE=1 STATUS_NO_DESKTOP_INTEGRATION=1 LIBGL_ALWAYS_SOFTWARE=1
export E2E_LOCAL_WAKU_FLEET=1 STATUS_FLEET=status-app.test
export STATUS_FLEET_CONFIG_FILE=/work/assets/local-waku-fleets-config.json

export SQUISH_DIR=$stand_in/squish_dir PYTHONPATH=$stand_in/api INSPECTOR_PLUGINS=/plugins
exec /work/ci/start-session-keyring.sh python3 -m pytest -p no:cacheprovider "$@"
