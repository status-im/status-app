## Option values (API keys, proxy credentials) that packaging adds to the app, see ci/README.md.

import std/[os, base64, strutils]
import nimcrypto/[rijndael, bcmode]

const
  BUILD_CONFIG_FILE_NAME* = "build-config"
  # Set by mobile/wrapperApp/sources/main.cpp.
  BUILD_CONFIG_CONTENT_ENV* = "STATUS_RUNTIME_BUILD_CONFIG"
  # 64 hex digits. With it the file is encrypted, without it plain JSON.
  BUILD_CONFIG_KEY = parseHexStr(getEnv("STATUS_CONFIG_KEY"))

static: doAssert BUILD_CONFIG_KEY.len in [0, 32], "STATUS_CONFIG_KEY must be 64 hex digits"

func bundledBuildConfigPath*(appDir: string): string =
  when defined(macosx):
    normalizedPath(appDir / ".." / "Resources" / BUILD_CONFIG_FILE_NAME)
  elif defined(windows) and defined(production):
    normalizedPath(appDir / ".." / "resources" / BUILD_CONFIG_FILE_NAME)
  else:
    normalizedPath(appDir / ".." / BUILD_CONFIG_FILE_NAME)

proc decryptBuildConfig*(content, key: string): string {.raises: [ValueError].} =
  ## `content` is "<iv in hex>:<AES-256-CTR ciphertext in base64>".
  let parts = content.strip().split(':', 1)
  if parts.len != 2:
    raise newException(ValueError, "not an encrypted build config")
  let
    iv = parseHexStr(parts[0])
    data = decode(parts[1])
  if iv.len != aes256.sizeBlock or data.len == 0:
    raise newException(ValueError, "not an encrypted build config")
  result = newString(data.len)
  var ctx: CTR[aes256]
  ctx.init(key.toOpenArrayByte(0, key.high), iv.toOpenArrayByte(0, iv.high))
  ctx.decrypt(data.toOpenArrayByte(0, data.high), result.toOpenArrayByte(0, result.high))
  ctx.clear()

proc readBuildConfig*(): string {.gcsafe, raises: [IOError, ValueError].} =
  ## The build config as JSON, or "" when the app has none.
  result = getEnv(BUILD_CONFIG_CONTENT_ENV)
  when appType != "lib" and appType != "staticlib":
    if result.len == 0:
      var path = ""
      try: path = bundledBuildConfigPath(getAppDir())
      except CatchableError: discard
      if fileExists(path):
        result = readFile(path)
  if result.len > 0 and BUILD_CONFIG_KEY.len > 0:
    result = decryptBuildConfig(result, BUILD_CONFIG_KEY)
