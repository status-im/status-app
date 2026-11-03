import std/[json, os, strutils]
import seaqt/qurl

proc convertUrlToLocalPath*(url: string): string =
  # fromUserInput trims absolute paths; whitespace can be part of a filename.
  if url.isAbsolute():
    return QUrl.fromLocalFile(url).toLocalFile()
  let parsed = QUrl.fromUserInput(
    url, getCurrentDir(), AssumeLocalFile(QUrlUserInputResolutionOptionEnum))
  if not parsed.isLocalFile():
    return ""
  return parsed.toLocalFile()

proc normalizeImageCropInfoJson*(imageCropInfoJson: string): (string, string) =
  var croppedImage = parseJson(imageCropInfoJson)
  let rawPath = croppedImage["imagePath"].getStr
  if rawPath.startsWith("data:") or rawPath.startsWith("http://") or rawPath.startsWith("https://"):
    return (imageCropInfoJson, rawPath)
  let imagePath = convertUrlToLocalPath(rawPath)
  if imagePath.len == 0 or imagePath == rawPath:
    return (imageCropInfoJson, rawPath)
  croppedImage["imagePath"] = %imagePath
  return ($croppedImage, imagePath)
