import std/[importutils, json, tables, unittest]
import app/core/eventemitter
import app/core/tasks/threadpool
import app_service/service/shared_urls/service
from seaqt/qcoreapplication import QCoreApplication, create

privateAccess(Service)

discard QCoreApplication.create()

const
  ProfileUrl = "https://status.app/u/profile#key"
  OtherUrl = "https://status.app/u/other#key"

suite "profile URL resolution":
  setup:
    let events = createEventEmitter()
    let service = newService(events, ThreadPool())
    # Hold the worker slot so the tests can control completion without an RPC.
    service.resolvingProfileUrls = @[OtherUrl]
    var completions: seq[JsonNode]
    events.on(SIGNAL_PROFILE_URLS_RESOLVED) do(args: Args):
      completions.add(parseJson(ProfileUrlsResolvedArgs(args).profilesJson))

  test "deduplicates pending URLs across and within messages":
    check service.resolveProfileUrls($(%* [ProfileUrl, ProfileUrl])) == "{}"
    check service.resolveProfileUrls($(%* [ProfileUrl])) == "{}"
    check service.pendingProfileUrls.len == 1
    check service.pendingProfileUrls[ProfileUrl] == 2
    check service.resolvingProfileUrls == @[OtherUrl]

    service.releaseProfileUrls($(%* [ProfileUrl, ProfileUrl]))
    check service.pendingProfileUrls[ProfileUrl] == 1
    service.releaseProfileUrls($(%* [ProfileUrl]))
    check service.pendingProfileUrls.len == 0

  test "recycling messages drops their queued work":
    for index in 0 ..< 500:
      let request = $(%* [ProfileUrl & $index])
      discard service.resolveProfileUrls(request)
      check service.pendingProfileUrls.len == 1
      service.releaseProfileUrls(request)
    service.onProfileUrlsResolved("{}")
    check service.pendingProfileUrls.len == 0
    check service.resolvingProfileUrls.len == 0
    check completions == @[newJObject()]

  test "limits queued URLs and accepts a retry after capacity is released":
    var initialUrls: seq[string]
    for index in 0 ..< 128:
      initialUrls.add(ProfileUrl & $index)
    discard service.resolveProfileUrls($(%initialUrls))
    check service.pendingProfileUrls.len == 128

    let request = $(%* [ProfileUrl])
    check parseJson(service.resolveProfileUrls(request)){ProfileUrl}.getBool(true) == false
    check not service.pendingProfileUrls.hasKey(ProfileUrl)

    service.releaseProfileUrls($(%* [initialUrls[0]]))
    check service.resolveProfileUrls(request) == "{}"
    check service.pendingProfileUrls.len == 128
    check service.pendingProfileUrls[ProfileUrl] == 1

  test "rejoining an in-flight URL shares its result and subsequent lookups hit the cache":
    let request = $(%* [OtherUrl])
    discard service.resolveProfileUrls(request)
    service.releaseProfileUrls(request)
    discard service.resolveProfileUrls(request)
    check service.resolvingProfileUrls == @[OtherUrl]

    let payload = %* {OtherUrl: {"publicKey": "key", "displayName": "Alice"}}
    service.onProfileUrlsResolved($payload)
    check completions == @[payload]
    check service.pendingProfileUrls.len == 0
    check parseJson(service.resolveProfileUrls(request)) == payload
    check service.resolvingProfileUrls.len == 0

  test "a failed lookup notifies active callers and is eligible for retry":
    let request = $(%* [OtherUrl])
    discard service.resolveProfileUrls(request)
    service.onProfileUrlsResolved("{}")
    check completions == @[%* {OtherUrl: nil}]
    check service.pendingProfileUrls.len == 0
    check not service.profileUrlCache.hasKey(OtherUrl)
