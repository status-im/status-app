import std/[strutils, uri]

# status-go serves chat/profile/community media over a local HTTP(S) server
# and embeds its ephemeral port in every URL it marshals. When that server
# restarts on a new port (mobile suspend/resume) it emits the
# `mediaserver.started` signal; subscribers use this helper to re-point
# cached URLs at the new port.

const MEDIA_SERVER_HOSTS = ["localhost", "127.0.0.1", "0.0.0.0"]

proc withMediaServerPort*(url: string, port: int): string =
  ## Rewrites the port of a loopback media-server URL. Anything else —
  ## empty strings, data URIs, remote URLs, port-less or already-current
  ## URLs — is returned unchanged, so callers can apply it blindly to any
  ## cached URL field.
  if url.len == 0 or port <= 0:
    return url
  let u = parseUri(url)
  if u.scheme != "http" and u.scheme != "https":
    return url
  if u.hostname notin MEDIA_SERVER_HOSTS:
    return url
  if u.port.len == 0 or u.port == $port:
    return url
  # Splice around the authority instead of re-serializing the parsed URI,
  # so the rest of the URL stays byte-identical (round-tripping through
  # parseUri can re-encode path/query characters).
  let hostPort = u.hostname & ":" & u.port
  let idx = url.find(hostPort)
  if idx < 0:
    return url
  url[0 ..< idx] & u.hostname & ":" & $port & url[idx + hostPort.len .. ^1]

template refreshMediaServerUrl*(field, port, changed: untyped) =
  ## Re-points `field` in place via `withMediaServerPort` and sets `changed`
  ## to true when the URL actually changed. `changed` is left untouched
  ## otherwise, so one flag can accumulate over several fields.
  let updated = withMediaServerPort(field, port)
  if updated != field:
    field = updated
    changed = true

# status-go media server defaults: TLS on, advertised as localhost
const MEDIA_SERVER_BASE = "https://localhost:"

proc contactImageUrl*(port: int, pubKey: string, clock: uint64): string =
  ## The contact thumbnail URL status-go's MakeContactImageURL builds (query
  ## keys sorted as url.Values.Encode does); empty without a port or an image.
  if port <= 0 or clock == 0:
    return ""
  MEDIA_SERVER_BASE & $port & "/contactImages?clock=" & $clock &
    "&imageName=thumbnail&publicKey=" & encodeUrl(pubKey)
