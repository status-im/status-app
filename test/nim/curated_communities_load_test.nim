import std/[json, tables, unittest]

import app/core/eventemitter
import app_service/service/community/service as community_service
import app_service/service/community/dto/community

const
  knownId = "0x02b5bdaf5a25fcfe2ee14c501fab1836b8de57f61621080c3d52073d16de0d98d6"
  unknownId = "0x024fa911c2a5a1a1b7f1a3a3a53a7d6a0c1e5c0a1b2c3d4e5f60718293a4b56501"

# the reply of wakuext_curatedCommunities as status-go returns it
const curatedReply = """{"jsonrpc":"2.0","id":7,"result":{
  "communities":{"""" & knownId & """":{"id":"""" & knownId & """","name":"Status"}},
  "unknownCommunities":["""" & unknownId & """"],
  "contractCommunities":["""" & knownId & """",""" & "\"" & unknownId & """"],
  "contractFeaturedCommunities":["""" & knownId & """"]}}"""

suite "loading the curated communities":
  setup:
    let events = createEventEmitter()
    let service = community_service.newService(events, nil, nil, nil, nil)

    var failed = 0
    var loaded: seq[CommunityDto]
    events.on(SIGNAL_CURATED_COMMUNITIES_LOADING_FAILED, proc(e: Args) = inc failed)
    events.on(SIGNAL_CURATED_COMMUNITIES_LOADED, proc(e: Args) =
      loaded = CommunitiesArgs(e).communities)

  test "the status-go reply is read as it is":
    service.onAsyncLoadCuratedCommunitiesDone(curatedReply)

    check failed == 0
    check loaded.len == 2
    check loaded[0].id == knownId
    check loaded[0].name == "Status"
    check loaded[0].listedInDirectory
    check loaded[0].featuredInDirectory
    check loaded[1].id == unknownId
    check loaded[1].listedInDirectory
    check not loaded[1].featuredInDirectory
    check service.getCommunityById(knownId).name == "Status"

  test "an error reply from status-go fails the load":
    service.onAsyncLoadCuratedCommunitiesDone(
      """{"jsonrpc":"2.0","id":7,"error":{"code":-32000,"message":"db closed"}}""")

    check failed == 1
    check loaded.len == 0

  test "a call that could not be made fails the load":
    service.onAsyncLoadCuratedCommunitiesDone($(%*{"error": "db closed due to profile migration"}))

    check failed == 1
    check loaded.len == 0
