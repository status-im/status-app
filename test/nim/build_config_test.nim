import std/[unittest, strutils]

import build_config

suite "build config file":

  test "the bundled file sits where packaging puts it":
    when defined(macosx):
      check bundledBuildConfigPath("/Applications/Status.app/Contents/MacOS") ==
        "/Applications/Status.app/Contents/Resources/build-config"
    elif defined(windows):
      check bundledBuildConfigPath("C:\\Status\\bin") == "C:\\Status\\build-config"
    else:
      check bundledBuildConfigPath("/tmp/AppDir/usr/bin") == "/tmp/AppDir/usr/build-config"

  test "decrypts what scripts/write-build-config.sh encrypts":
    # printf '<json>' | openssl enc -aes-256-ctr -K <key> -iv <iv> -a -A
    const
      key = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
      content = "ffffffffffffffffffffffffffffff00:4tVUaKViv5qpJp5QhwkrzrbhIJZuJWAYPQXioGT3ias4+7qr8RVgEIrwIn+X1CUC+oF7RQn24IdDEwkrDoCoj/xSVc2x/T5c"
    check decryptBuildConfig(content, parseHexStr(key)) ==
      """{"INFURA_TOKEN": "abc", "POKT_TOKEN": "a-longer-value-to-cross-a-block"}"""

  test "rejects a file that is not encrypted":
    expect ValueError:
      discard decryptBuildConfig("""{"INFURA_TOKEN": "abc"}""", "00")
