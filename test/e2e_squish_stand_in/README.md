# Squish stand-in for the desktop e2e suite

Runs the desktop suite (`test/e2e`) without Squish. The suite imports Squish's
Python modules (`squishtest`, `squish`, `object`, `toplevelwindow`,
`objectmaphelper`). This directory provides modules with the same names and
the same functions. They talk to the Qt inspector plugin inside the app, not
to Squish. The plugin's source is in its own repository,
[status-qml-inspector](https://github.com/status-im/status-qml-inspector).

The test files are not changed. One page object has a new wait and the object
map has one new entry (see "Differences from Squish"). No Squish install and no
Squish license are needed.

## Status

Experimental. Linux only. Squish stays the suite's default. A Squish run does
not use this directory.

Tried: the 14 tests in `tests/critical_tests_prs` and the 5 tests in
`tests/onboarding`. All 19 can pass; see the known problems for the ones that
sometimes fail. Not tried: the other tests, including
keycard and file dialogs. Not started: Windows and macOS.

Known problems:

- `test_personal_sign_in_browser` is not stable. In some runs the test page
  never gets `window.ethereum` and its title becomes `no-provider`. It happens
  when the browser's start page (`https://status.app`, from the internet) takes
  longer than about one second to load. The cause is not found.
- The app sometimes crashes (SIGSEGV) in a test with two apps, after the click
  that opens the Messages screen. Seen in 5 of 42 full runs. It is a bug
  in Qt 6.11.0, which the app ships: QTBUG-148459, a missing null check in
  `QQmlConnections::connectSignalsToMethods()`. Qt fixed it in its `6.11`
  branch after 6.11.0 (qtdeclarative commit `c89b2cf16d`). The plugin is not
  on the crash stack. It is not known if the crash also happens under Squish.

Security: `run.sh` runs the container on the host's network, as the Jenkins job
does. During a run, any process on the same machine can connect to the plugin's
port on `127.0.0.1` and run QML in the app under test. The port is not reachable
from other machines. Do not run this on a machine you share with users you do
not trust.

## Layout

| Path | What it is |
|---|---|
| `api/` | The Python modules. Goes on `PYTHONPATH` in place of Squish's `lib/python`. |
| `squish_dir/bin/` | `startaut` and `squishserver` replacements. `SQUISH_DIR` points at `squish_dir`. |
| `build-plugin.sh` | Fetches the inspector plugin at a pinned commit and builds it for Linux desktop. |
| `docker/`, `run.sh` | Run the suite in the suite's CI image. |
| `tests/` | Unit tests for the lookup and typing rules. No app needed. |

## Run the suite

You need Docker, and a Linux build of the app made with Qt 6.11.0. The app is
not rebuilt: the plugin is loaded into it at start.

1. Build the suite's CI image, then add `xdotool` to it. The first command
   needs access to `harbor.status.im` for the base image. The build image that
   `ci.yml` publishes (`ci/build-image.sh --image desktop`) also works as the
   base, if you change the `FROM` line:

   ```bash
   docker build -t status-e2e-tests -f ci/tests.Dockerfile ci
   docker build -t status-e2e-squish-stand-in test/e2e_squish_stand_in/docker
   ```

2. Build the plugin. The script clones the plugin repository at a pinned
   commit. To build a local checkout of it, set `PLUGIN_SRC=<path>`:

   ```bash
   test/e2e_squish_stand_in/build-plugin.sh /tmp/qmlinspector
   ```

3. Unpack the app. `Status.AppImage` is in `Status.tar.gz` of the
   `Status-linux-x86_64` artifact of the `ci.yml` workflow:

   ```bash
   tar -xzf Status.tar.gz
   ./Status.AppImage --appimage-extract
   ```

4. Run tests. Arguments go to pytest, which starts in `test/e2e`:

   ```bash
   APP=$PWD/squashfs-root/AppRun PLUGINS=/tmp/qmlinspector/plugins \
     test/e2e_squish_stand_in/run.sh tests/critical_tests_prs tests/onboarding
   ```

`run.sh` starts the local Waku fleet, then runs pytest in the image with Xvfb,
`fluxbox` and a session keyring, as `ci/Jenkinsfile.tests-e2e` does for Squish.

To see why a lookup found nothing, set `SQUISH_STAND_IN_LOOKUP_LOG=/state/lookup.log`.
The file appears in `~/.cache/status-e2e-squish-stand-in/`. Each line shows how
many objects were left after each rule of the object-map entry.

## Unit tests

```bash
cd test/e2e_squish_stand_in
python -m pytest
```

## How an object-map entry is matched

These rules copy what Squish does. Each one was needed by at least one test.
The code is in `api/lookup.py`.

- `type` matches the object's QML type or any of its base types. Generated
  suffixes (`_QMLTYPE_42`) and Qt's `QQuick` prefix are ignored.
- `id` is the QML `id`.
- `unnamed` keeps only objects with an empty `objectName`.
- A `RegularExpression` or `Wildcard` value matches anywhere in the value.
- Any other key is a property of the object. If the object has no such
  property, the key is read from the object's QML context. This is how
  `index` of a list delegate works.
- `occurrence` counts from 1.
- An open popup is found although it is not a child item of the window.

## How input is sent

Mouse, wheel and key input enter Qt where the platform plugin delivers real
input, as QTest does. Hover, focus, grabs and shortcuts behave as for a user.
Before a click, the stand-in waits until the item has stopped moving.

`nativeMouseClick` is the exception: it uses `xdotool`, so the click comes
from the X server.

## Differences from Squish

- Only the Squish functions the 19 tests use exist. Another one fails with an
  error that names it when a test first calls it. `object.parent` is one.
- Timing differs. A test with a hidden race can fail here. One did:
  `BrowserScreen.open_url` now waits for the start page. That wait is in the
  suite, so it also runs under Squish. If the start page never loads, it costs
  15 seconds.
- `isFrozen` always returns false.
