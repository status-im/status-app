import std/[json, tables, unittest]

import app/core/eventemitter
import app_service/service/community/service as community_service
import app_service/service/community/dto/community

const
  knownId = "0x02b5bdaf5a25fcfe2ee14c501fab1836b8de57f61621080c3d52073d16de0d98d6"
  unknownId = "0x024fa911c2a5a1a1b7f1a3a3a53a7d6a0c1e5c0a1b2c3d4e5f60718293a4b56501"

# the reply of wakuext_curatedCommunities as status-go returns it
const curatedReply = """{"jsonrpc":"2.0","id":7,"result":{
  "communities":{"""" & knownId & """":{"id":"""" & knownId & """","name":"Status","description":"Messenger"}},
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

const
  featuredUnknownId = "0x03aa11c2a5a1a1b7f1a3a3a53a7d6a0c1e5c0a1b2c3d4e5f60718293a4b56502"
  listedReply = """{"jsonrpc":"2.0","id":8,"result":{
  "communities":{},
  "unknownCommunities":["""" & unknownId & """",""" & "\"" & featuredUnknownId & """"],
  "contractCommunities":["""" & unknownId & """",""" & "\"" & featuredUnknownId & """"],
  "contractFeaturedCommunities":["""" & featuredUnknownId & """"]}}"""

proc fetched(id: string): CommunityDto =
  CommunityDto(id: id, name: "Fetched", description: "From a store node")

suite "a curated community arriving from a store node":
  setup:
    let events = createEventEmitter()
    let service = community_service.newService(events, nil, nil, nil, nil)

    var found: seq[CommunityDto]
    var loaded: seq[CommunityDto]
    events.on(SIGNAL_CURATED_COMMUNITY_FOUND, proc(e: Args) = found.add(CommunityArgs(e).community))
    events.on(SIGNAL_CURATED_COMMUNITIES_LOADED, proc(e: Args) =
      loaded = CommunitiesArgs(e).communities)

  test "it fills the entry the directory listed as unknown":
    service.onAsyncLoadCuratedCommunitiesDone(listedReply)

    service.onCommunityFound(fetched(unknownId))

    check found.len == 1
    check found[0].id == unknownId
    check found[0].name == "Fetched"
    check found[0].isAvailable
    check found[0].listedInDirectory
    check not found[0].featuredInDirectory
    check service.getCommunityById(unknownId).listedInDirectory

  test "it keeps a featured entry featured":
    service.onAsyncLoadCuratedCommunitiesDone(listedReply)

    service.onCommunityFound(fetched(featuredUnknownId))

    check found.len == 1
    check found[0].featuredInDirectory
    check found[0].listedInDirectory

  test "a community that is not in the directory is not a curated one":
    service.onAsyncLoadCuratedCommunitiesDone(listedReply)

    service.onCommunityFound(fetched(knownId))

    check found.len == 0

  test "arriving before the directory was read, it is taken from the read":
    service.onCommunityFound(fetched(knownId))
    check found.len == 0

    service.onAsyncLoadCuratedCommunitiesDone(curatedReply)

    check loaded.len == 2
    check loaded[0].id == knownId
    check loaded[0].name == "Status"
    check loaded[0].listedInDirectory
    check service.getCommunityById(knownId).listedInDirectory

  test "arriving during a read that already holds it, the read gives the same entry":
    service.onAsyncLoadCuratedCommunitiesDone(listedReply)
    service.onCommunityFound(fetched(featuredUnknownId))

    service.onAsyncLoadCuratedCommunitiesDone("""{"jsonrpc":"2.0","id":9,"result":{
      "communities":{"""" & featuredUnknownId & """":{"id":"""" & featuredUnknownId & """","name":"Fetched","description":"From a store node"}},
      "unknownCommunities":["""" & unknownId & """"],
      "contractCommunities":["""" & unknownId & """",""" & "\"" & featuredUnknownId & """"],
      "contractFeaturedCommunities":["""" & featuredUnknownId & """"]}}""")

    check loaded.len == 2
    check loaded[0].id == featuredUnknownId
    check loaded[0].isAvailable
    check loaded[0].featuredInDirectory
    check loaded[0].name == found[0].name
    check loaded[0].listedInDirectory

  test "a read made before it arrived does not turn it back into an unknown entry":
    service.onAsyncLoadCuratedCommunitiesDone(listedReply)
    service.onCommunityFound(fetched(featuredUnknownId))

    service.onAsyncLoadCuratedCommunitiesDone(listedReply)

    check loaded.len == 2
    check loaded[1].id == featuredUnknownId
    check loaded[1].name == "Fetched"
    check loaded[1].isAvailable
    check loaded[1].featuredInDirectory
    check not loaded[0].isAvailable
    check service.getCommunityById(featuredUnknownId).isAvailable

  test "a read that no longer lists it does not bring it back":
    service.onAsyncLoadCuratedCommunitiesDone(listedReply)
    service.onCommunityFound(fetched(featuredUnknownId))

    service.onAsyncLoadCuratedCommunitiesDone("""{"jsonrpc":"2.0","id":10,"result":{
      "communities":{},
      "unknownCommunities":["""" & unknownId & """"],
      "contractCommunities":["""" & unknownId & """"],
      "contractFeaturedCommunities":[]}}""")

    check loaded.len == 1
    check loaded[0].id == unknownId
    check not loaded[0].isAvailable
