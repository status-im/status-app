import std/[json, os, strutils, tempfiles, unittest]

import app_service/common/local_path
import backend/interpret/cropped_image

const cropRect = """{"x":0,"y":20,"width":1300,"height":1300}"""
const windowsDrivePath = "/J:/Users/jenkins/workspace/comm_logo.jpeg"
const windowsLocalPath = "J:/Users/jenkins/workspace/comm_logo.jpeg"
const linuxPath = "/home/jenkins/comm_logo.jpeg"
const linuxPathWithPlusAndHash = "/home/jenkins/a+b/#c.jpeg"

when defined(windows):
  const driveFileLocalPath = "J:/Users/jenkins/workspace/comm_logo.jpeg"
  const encodedDriveLocalPath = "J:/Users/jenkins/my logo.jpeg"
else:
  const driveFileLocalPath = "/J:/Users/jenkins/workspace/comm_logo.jpeg"
  const encodedDriveLocalPath = "/J:/Users/jenkins/my logo.jpeg"

proc cropJson(imagePath: string, cropRectJson = cropRect): string =
  $(%*{"imagePath": imagePath, "cropRect": parseJson(cropRectJson)})

suite "local path for community token artwork":

  test "Windows drive path is a local file":
    let (normalizedJson, imagePath) = normalizeImageCropInfoJson(cropJson(windowsDrivePath))
    check imagePath == driveFileLocalPath
    check newCroppedImage(normalizedJson).imagePath == driveFileLocalPath

  test "file URI and bare drive path follow QUrl":
    check convertUrlToLocalPath("file:///" & windowsLocalPath) == driveFileLocalPath
    check convertUrlToLocalPath("file:/home/jenkins/comm_logo.jpeg") == linuxPath
    when defined(windows):
      check convertUrlToLocalPath(windowsLocalPath) == windowsLocalPath
    else:
      let (unchangedJson, imagePath) = normalizeImageCropInfoJson(cropJson(windowsLocalPath))
      check convertUrlToLocalPath(windowsLocalPath) == ""
      check unchangedJson == cropJson(windowsLocalPath)
      check imagePath == windowsLocalPath

  test "Unix paths keep a leading slash, including + and #":
    let (unchangedJson, imagePath) = normalizeImageCropInfoJson(cropJson(linuxPath))
    check unchangedJson == cropJson(linuxPath)
    check imagePath == linuxPath
    check convertUrlToLocalPath("file://" & linuxPath) == linuxPath
    check convertUrlToLocalPath(linuxPathWithPlusAndHash) == linuxPathWithPlusAndHash
    check normalizeImageCropInfoJson(cropJson(linuxPathWithPlusAndHash))[1] == linuxPathWithPlusAndHash

  test "encoded characters in a file URI are decoded before the file is opened":
    let (normalizedJson, imagePath) = normalizeImageCropInfoJson(
      cropJson("file:///J:/Users/jenkins/my%20logo.jpeg", """{"x":1,"y":2,"width":3,"height":4}"""))
    check imagePath == encodedDriveLocalPath
    let crop = newCroppedImage(normalizedJson)
    check crop.x == 1 and crop.y == 2 and crop.width == 3 and crop.height == 4
    check convertUrlToLocalPath("file:///home/jenkins/my%2Blogo%23x.jpeg") == "/home/jenkins/my+logo#x.jpeg"
    check convertUrlToLocalPath("file:///home/jenkins/workspace/status-app/e2e/prs%402/ext/test_images/comm_banner.jpeg") ==
      "/home/jenkins/workspace/status-app/e2e/prs@2/ext/test_images/comm_banner.jpeg"

  test "empty input is not a local file":
    check convertUrlToLocalPath("") == ""
    check convertUrlToLocalPath("   ") == ""

  test "relative paths resolve against the current directory":
    let cwd = getCurrentDir().replace('\\', '/')
    check convertUrlToLocalPath("artwork/logo.jpeg") == cwd & "/artwork/logo.jpeg"
    check convertUrlToLocalPath("./logo.jpeg") == cwd & "/logo.jpeg"
    let (normalizedJson, imagePath) = normalizeImageCropInfoJson(cropJson("artwork/logo.jpeg"))
    check imagePath == cwd & "/artwork/logo.jpeg"
    check newCroppedImage(normalizedJson).imagePath == imagePath

  test "inline and remote images are not rewritten":
    for remotePath in ["data:image/png;base64,abc", "http://example.com/a.png",
        "https://example.com/a.png", "HTTPS://example.com/a.png",
        "content://com.android.providers.media.documents/document/image%3A123",
        "assets-library://asset/asset.JPG?id=123&ext=JPG", "ph://123"]:
      let input = cropJson(remotePath, """{"x":0,"y":0,"width":1,"height":1}""")
      let (unchangedJson, imagePath) = normalizeImageCropInfoJson(input)
      check convertUrlToLocalPath(remotePath) == ""
      check unchangedJson == input
      check imagePath == remotePath

  test "desktop and resolved mobile sandbox file URLs":
    for path in [
        "/home/user/Pictures/my logo.png",
        "/Users/user/Pictures/my logo.png",
        "/data/user/0/im.status.ethereum/cache/my logo.png",
        "/storage/emulated/0/Pictures/my logo.png",
        "/private/var/mobile/Containers/Data/Application/ABC/tmp/my logo.png"]:
      let uri = "file://" & path.replace(" ", "%20")
      check convertUrlToLocalPath(uri) == path
      check convertUrlToLocalPath("file:" & path.replace(" ", "%20")) == path
      let (normalizedJson, imagePath) = normalizeImageCropInfoJson(cropJson(uri))
      check imagePath == path
      check newCroppedImage(normalizedJson).imagePath == path
      check normalizeImageCropInfoJson(normalizedJson) == (normalizedJson, path)

  test "UNC file URLs retain the server and share":
    check convertUrlToLocalPath("file://server/share/my%20logo.png") ==
      "//server/share/my logo.png"
    check convertUrlToLocalPath("//server/share/my logo.png") ==
      "//server/share/my logo.png"
    when defined(windows):
      check convertUrlToLocalPath(r"\\server\share\my logo.png") ==
        "//server/share/my logo.png"
      check convertUrlToLocalPath(r"J:\Users\jenkins\my logo.png") ==
        "J:/Users/jenkins/my logo.png"

  test "literal whitespace in paths is not trimmed":
    let relativePath = " artwork/logo.png"
    let expected = getCurrentDir().replace('\\', '/') & "/" & relativePath
    check convertUrlToLocalPath(relativePath) == expected
    when not defined(windows):
      check convertUrlToLocalPath("/tmp/logo.png ") == "/tmp/logo.png "
      check convertUrlToLocalPath("artwork/logo.png ") ==
        getCurrentDir() & "/artwork/logo.png "

  test "normalized artwork paths open the same file and decode only once":
    let dir = createTempDir("status-local-path-", "")
    let filename = "a+b #c %20 \xC3\xA9.png" & (when defined(windows): "" else: " ")
    let path = (dir / filename).replace('\\', '/')
    let encodedPath = path.replace("%", "%25").replace(" ", "%20")
      .replace("+", "%2B").replace("#", "%23").replace("\xC3\xA9", "%C3%A9")
    let uri = when defined(windows): "file:///" & encodedPath
              else: "file://" & encodedPath
    try:
      writeFile(path, "artwork")
      for inputPath in [path, uri]:
        let (normalizedJson, imagePath) = normalizeImageCropInfoJson(cropJson(inputPath))
        check imagePath == path
        check newCroppedImage(normalizedJson).imagePath == path
        check normalizeImageCropInfoJson(normalizedJson) == (normalizedJson, path)
        check readFile(imagePath) == "artwork"
    finally:
      removeFile(path)
      removeDir(dir)
