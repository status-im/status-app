import std/unittest

import build_config

suite "build config file":

  test "the bundled file sits where packaging puts it":
    when defined(macosx):
      check bundledBuildConfigPath("/Applications/Status.app/Contents/MacOS") ==
        "/Applications/Status.app/Contents/Resources/build-config.json"
    elif defined(windows):
      check bundledBuildConfigPath("C:\\Status\\bin") == "C:\\Status\\build-config.json"
    else:
      check bundledBuildConfigPath("/tmp/AppDir/usr/bin") == "/tmp/AppDir/usr/build-config.json"

  test "no file is found when the bundle has none":
    check buildConfigPath() == ""
