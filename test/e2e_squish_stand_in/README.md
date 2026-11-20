# Squish stand-in for the desktop e2e suite

Runs the desktop suite (`test/e2e`) without Squish. "Stand-in" means a
replacement that has the same function names.

Nothing from Squish is installed or used: no Squish file, no Squish code and
no license.

How it works:

- The test code has lines such as `import squish` and `import squishtest`,
  and it starts programs named `startaut` and `squishserver`.
- This directory has its own modules and programs with those names. They were
  written for this purpose.
- They send commands to a Qt plugin that is loaded into the app. The plugin
  finds QML objects and sends mouse and key input. Its source is in
  [status-qml-inspector](https://github.com/status-im/status-qml-inspector).
- The test files do not change.

## Status

Experimental. Linux only. Squish is still the default way to run the suite. A
Squish run does not use this directory.

- Tried: 19 tests. These are the 14 tests in `tests/critical_tests_prs` and
  the 5 tests in `tests/onboarding`.
- Result: 16 to 18 of the 19 pass in a run. "Known problems" lists the tests
  that fail.
- Not tried: all other tests, for example keycard tests and tests that use a
  file dialog.
- Not started: Windows and macOS.

## Try it

You need:

- A Linux x86_64 machine with Docker. macOS and Windows do not work yet.
- About 20 GB of free disk space.
- About 30 minutes for the first run. Later runs of the 19 tests take about
  10 minutes.

Run all commands from the root of the repository.

1. Build the test image. This is the image that the Jenkins job uses for
   Squish, plus the `xdotool` program. The first command downloads a base
   image from `harbor.status.im`.

   ```bash
   docker build -t status-e2e-tests -f ci/tests.Dockerfile ci
   docker build -t status-e2e-squish-stand-in test/e2e_squish_stand_in/docker
   ```

2. Build the plugin. The script downloads the plugin's source and Qt 6.11.0.

   ```bash
   test/e2e_squish_stand_in/build-plugin.sh /tmp/qmlinspector
   ```

3. Get a Linux build of the app. Open a run of the `CI` workflow on the
   repository's "Actions" page (for `master` or for a pull request) and
   download the artifact `Status-linux-x86_64`. Unzip it, then:

   ```bash
   tar -xzf Status.tar.gz
   ./Status.AppImage --appimage-extract
   ```

   This creates the directory `squashfs-root`. The app is used as it is. It is
   not rebuilt.

4. Run the tests. The arguments after `run.sh` go to pytest, so you can also
   give one test file or use `-k`.

   ```bash
   APP=$PWD/squashfs-root/AppRun PLUGINS=/tmp/qmlinspector/plugins \
     test/e2e_squish_stand_in/run.sh tests/critical_tests_prs tests/onboarding
   ```

What to expect:

- The last line of the output looks like `2 failed, 17 passed`. This is a
  normal result today. See "Known problems".
- Logs and the screenshots of failed tests are in
  `test/e2e/local_run_results/`.
- The app windows are not shown on your screen. They are drawn on a virtual
  screen inside the container.

If you cannot download from `harbor.status.im`: change the first line of
`ci/tests.Dockerfile` to `FROM <image>`, where `<image>` is the output of
`ci/build-image.sh --image desktop`. Then run step 1 again. This also worked.
For that image, Docker must be logged in to `ghcr.io` with an account that can
read the packages of `status-im`.

## Known problems

- **`test_personal_sign_in_browser` fails in many runs.** The test page does
  not get `window.ethereum`, so the "sign" button stays disabled. The cause is
  not found. It is not known if this also happens with Squish.
- **`test_stay_logged_in_opt_in_survives_sign_out` fails in every run.** This
  is a problem in the suite on `master`. It does not depend on Squish.
  `helpers/onboarding_helper.py` calls `open_sign_out_and_quit`, but commit
  `c721dc4351` changed that name to `open_sign_out`.
- **The app sometimes crashes in a test that uses two apps.** Seen in 5 of 42
  runs, after the click that opens the Messages screen.
  - The cause is a bug in Qt 6.11.0, the Qt version of the app: QTBUG-148459.
  - Qt has fixed it in a later 6.11 version (qtdeclarative commit
    `c89b2cf16d`).
  - The crash is in Qt's code, not in the plugin's code.
  - It is not known if the crash also happens with Squish.
- **The browser test needs one fix in the suite.** `BrowserScreen.open_url`
  must wait for the browser's start page. This fix is in pull request
  [#23247](https://github.com/status-im/status-app/pull/23247). The same wait
  then also runs with Squish.

## Security

Run this only on a machine where you trust all users.

During a run, the plugin listens on a port on `127.0.0.1`. It has no password.
Any program on the same machine can connect to it and run QML code in the app
that is tested. Other machines cannot connect.

The reason: `run.sh` gives the container the network of the host, as the
Jenkins job does for Squish.

## Reference

You do not need this section to try the tests.

### Files

| Path | What it is |
|---|---|
| `api/` | Our Python modules. `PYTHONPATH` points here. |
| `squish_dir/bin/` | Our `startaut` and `squishserver`. `SQUISH_DIR` points at `squish_dir`. |
| `build-plugin.sh` | Downloads one fixed commit of the plugin and builds it for Linux. |
| `docker/`, `run.sh` | Run the suite in the test image. |
| `tests/` | Unit tests for the rules below. They do not need the app. |

`run.sh` starts the local Waku fleet. Then it runs pytest in the image with
Xvfb, `fluxbox` and a session keyring, as `ci/Jenkinsfile.tests-e2e` does.

To build the plugin from your own copy of its source, set `PLUGIN_SRC=<path>`
for `build-plugin.sh`.

### Unit tests

```bash
cd test/e2e_squish_stand_in
python -m pytest
```

### How an object is found

The suite describes each object with an entry in its object map. These rules
do the same as Squish. Each rule was needed by at least one test. The code is
in `api/lookup.py`.

- `type` matches the QML type of the object, or one of its base types. Endings
  such as `_QMLTYPE_42` and the `QQuick` prefix are ignored.
- `id` is the QML `id`.
- `unnamed` keeps only objects that have an empty `objectName`.
- A `RegularExpression` or `Wildcard` value matches any part of the value.
- Every other key is a property of the object. If the object has no property
  with that name, the name is looked up in the object's QML context. The
  `index` of an item in a list works this way.
- `occurrence` counts from 1.
- An open popup is found, although it is not a child of the window.

When a test cannot find an object, this shows why: set
`SQUISH_STAND_IN_LOOKUP_LOG=/state/lookup.log` before `run.sh`. The file is
then in `~/.cache/status-e2e-squish-stand-in/`. Each line shows how many
objects were left after each rule.

### How input is sent

- Mouse, wheel and key input are given to Qt in the same place where real
  input from the system arrives. QTest does the same. So hover, focus and
  keyboard shortcuts work as they do for a user.
- Before a click, the stand-in waits until the item has stopped moving.
- `nativeMouseClick` is different: it uses `xdotool`, so the click comes from
  the X server.

### Differences from Squish

- Only the Squish functions that the 19 tests use exist. If a test calls
  another one, it fails with an error that gives the function's name.
  `object.parent` is an example.
- The timing is different. A test that only passed because Squish was slower
  or faster at some point can fail here. The browser test was such a case.
- `isFrozen` always returns false.
