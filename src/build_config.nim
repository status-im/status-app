## Option values (API keys, proxy credentials) that packaging adds to the app, see ci/README.md.

import os

const
  BUILD_CONFIG_FILE_NAME* = "build-config.json"
  # Set by mobile/wrapperApp/sources/main.cpp.
  BUILD_CONFIG_CONTENT_ENV* = "STATUS_RUNTIME_BUILD_CONFIG_JSON"

func bundledBuildConfigPath*(appDir: string): string =
  when defined(macosx):
    normalizedPath(appDir / ".." / "Resources" / BUILD_CONFIG_FILE_NAME)
  elif defined(windows) and defined(production):
    normalizedPath(appDir / ".." / "resources" / BUILD_CONFIG_FILE_NAME)
  else:
    normalizedPath(appDir / ".." / BUILD_CONFIG_FILE_NAME)

proc buildConfigPath*(): string {.gcsafe, raises: [].} =
  when appType == "lib" or appType == "staticlib":
    ""
  else:
    try:
      let path = bundledBuildConfigPath(getAppDir())
      if fileExists(path): path else: ""
    except CatchableError:
      ""
