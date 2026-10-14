import unittest

import app_service/common/media_server_url

# status-go mints absolute media URLs (https://localhost:<port>/...) at
# marshal time. When the media server restarts on a new port (iOS
# background/resume), cached URLs must be re-pointed — and only those:
# the helper must be a safe no-op for every other string so callers can
# apply it blindly to any cached URL field (issue #47).

suite "withMediaServerPort":

  test "rewrites the port of a localhost media URL, preserving path and query":
    check withMediaServerPort("https://localhost:34567/messages/images?messageId=0xabc", 40000) ==
      "https://localhost:40000/messages/images?messageId=0xabc"

  test "rewrites http and 127.0.0.1 forms too":
    check withMediaServerPort("http://127.0.0.1:1234/accountImages?keyUid=0x1&imageName=thumbnail", 999) ==
      "http://127.0.0.1:999/accountImages?keyUid=0x1&imageName=thumbnail"

  test "keeps an already-current port untouched":
    let url = "https://localhost:40000/messages/images?messageId=0xabc"
    check withMediaServerPort(url, 40000) == url

  test "no-op for empty strings and non-positive ports":
    check withMediaServerPort("", 40000) == ""
    check withMediaServerPort("https://localhost:34567/x", 0) == "https://localhost:34567/x"
    check withMediaServerPort("https://localhost:34567/x", -1) == "https://localhost:34567/x"

  test "no-op for data URIs":
    let dataUri = "data:image/png;base64,iVBORw0KGgo="
    check withMediaServerPort(dataUri, 40000) == dataUri

  test "no-op for remote URLs, with or without an explicit port":
    check withMediaServerPort("https://example.com/img.png", 40000) ==
      "https://example.com/img.png"
    check withMediaServerPort("https://example.com:8080/img.png", 40000) ==
      "https://example.com:8080/img.png"

  test "no-op for local URLs without an explicit port":
    # The media server always embeds its ephemeral port; a port-less
    # localhost URL is not one of its URLs.
    check withMediaServerPort("https://localhost/img.png", 40000) ==
      "https://localhost/img.png"

  test "no-op for non-http schemes and plain paths":
    check withMediaServerPort("qrc:/imports/assets/x.svg", 40000) == "qrc:/imports/assets/x.svg"
    check withMediaServerPort("file:///tmp/x.png", 40000) == "file:///tmp/x.png"
    check withMediaServerPort("/tmp/x.png", 40000) == "/tmp/x.png"

  test "a port embedded in the query string is not touched":
    check withMediaServerPort("https://localhost:34567/proxy?u=http://localhost:34567/a", 40000) ==
      "https://localhost:40000/proxy?u=http://localhost:34567/a"

suite "contactImageUrl":

  test "matches status-go MakeContactImageURL for the thumbnail":
    check contactImageUrl(40000, "0x04ab", 1712345678'u64) ==
      "https://localhost:40000/contactImages?clock=1712345678&imageName=thumbnail&publicKey=0x04ab"

  test "no URL without a known port or image":
    check contactImageUrl(0, "0x04ab", 7) == ""
    check contactImageUrl(40000, "0x04ab", 0) == ""
