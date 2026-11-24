import std/[json, unittest]

import app/core/eventemitter
import app/core/signals/types
import app/global/app_signals
import app_service/service/community/service as community_service
import app_service/service/community/curated_directory
import app_service/service/community/dto/community

const
  knownId = "0x02b5bdaf5a25fcfe2ee14c501fab1836b8de57f61621080c3d52073d16de0d98d6"
  unknownId = "0x024fa911c2a5a1a1b7f1a3a3a53a7d6a0c1e5c0a1b2c3d4e5f60718293a4b56501"

# the reply of the curatedCommunities RPC as status-go returns it
const curatedReply = """{"jsonrpc":"2.0","id":7,"result":{
  "communities":{"""" & knownId & """":{"id":"""" & knownId & """","name":"Status","description":"Messenger"}},
  "unknownCommunities":["""" & unknownId & """"],
  "contractCommunities":["""" & knownId & """",""" & "\"" & unknownId & """"],
  "contractFeaturedCommunities":["""" & knownId & """"]}}"""

suite "loading the curated communities":
  setup:
    let events = createEventEmitter()
    let service = community_service.newService(events, nil, nil, nil, nil)

    var loads = 0
    var loaded: seq[CommunityDto]
    events.on(SIGNAL_CURATED_COMMUNITIES_LOADED, proc(e: Args) =
      inc loads
      loaded = CommunitiesArgs(e).communities)

  test "the status-go reply is read as it is":
    service.onAsyncLoadCuratedCommunitiesDone(curatedReply)

    check loads == 1
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

    check loads == 0

  test "a call that could not be made fails the load":
    service.onAsyncLoadCuratedCommunitiesDone($(%*{"error": "db closed due to profile migration"}))

    check loads == 0

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

  test "an entry listed since the last read is unknown after the next read and filled when it arrives":
    service.onAsyncLoadCuratedCommunitiesDone(curatedReply)
    check loaded.len == 2

    service.onAsyncLoadCuratedCommunitiesDone("""{"jsonrpc":"2.0","id":11,"result":{
      "communities":{"""" & knownId & """":{"id":"""" & knownId & """","name":"Status","description":"Messenger"}},
      "unknownCommunities":["""" & unknownId & """",""" & "\"" & featuredUnknownId & """"],
      "contractCommunities":["""" & knownId & """",""" & "\"" & unknownId & """",""" & "\"" & featuredUnknownId & """"],
      "contractFeaturedCommunities":["""" & knownId & """"]}}""")

    check loaded.len == 3
    check loaded[2].id == featuredUnknownId
    check not loaded[2].isAvailable
    check found.len == 0

    service.onCommunityFound(fetched(featuredUnknownId))

    check found.len == 1
    check found[0].id == featuredUnknownId
    check found[0].isAvailable
    check found[0].listedInDirectory

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

  test "an entry the directory no longer lists is not a curated one when it arrives":
    service.onAsyncLoadCuratedCommunitiesDone(listedReply)
    service.onAsyncLoadCuratedCommunitiesDone("""{"jsonrpc":"2.0","id":12,"result":{
      "communities":{},
      "unknownCommunities":["""" & unknownId & """"],
      "contractCommunities":["""" & unknownId & """"],
      "contractFeaturedCommunities":[]}}""")

    service.onCommunityFound(fetched(featuredUnknownId))

    check found.len == 0
    check not service.getCommunityById(featuredUnknownId).listedInDirectory
    check not service.getCommunityById(featuredUnknownId).featuredInDirectory
    check service.getCommunityById(unknownId).listedInDirectory

  test "a read that failed leaves the listed entries as they were":
    service.onAsyncLoadCuratedCommunitiesDone(listedReply)
    service.onAsyncLoadCuratedCommunitiesDone(
      """{"jsonrpc":"2.0","id":13,"error":{"code":-32000,"message":"db closed"}}""")

    service.onCommunityFound(fetched(featuredUnknownId))

    check found.len == 1
    check found[0].featuredInDirectory

suite "the curated refresh as the service forwards it":
  setup:
    let events = createEventEmitter()
    let service = community_service.newService(events, nil, nil, nil, nil)
    service.doConnect()

    var loading: seq[bool]
    events.on(SIGNAL_CURATED_COMMUNITIES_LOADING, proc(e: Args) =
      loading.add(CuratedCommunitiesLoadingArgs(e).loading))

    var errors: seq[int]
    events.on(SIGNAL_CURATED_COMMUNITIES_REFRESH_ERROR, proc(e: Args) =
      errors.add(CuratedCommunitiesRefreshErrorArgs(e).error))

    proc started(directoryFailed = false) =
      events.emit(SignalType.CuratedCommunitiesRefreshStarted.event,
        CuratedCommunitiesRefreshStartedSignal(
          signalType: SignalType.CuratedCommunitiesRefreshStarted, directoryFailed: directoryFailed))

    proc finished(cancelled = false, failed = 0) =
      events.emit(SignalType.CuratedCommunitiesRefreshFinished.event,
        CuratedCommunitiesRefreshFinishedSignal(
          signalType: SignalType.CuratedCommunitiesRefreshFinished, failed: failed, cancelled: cancelled))

  test "without a node and a thread pool, entering the portal does not leave it loading":
    service.refreshCuratedCommunities()

    check loading.len == 0

  test "a refresh is loading from its start to its end while the portal is open":
    service.refreshCuratedCommunities()

    started()
    check loading == @[true]

    finished()
    check loading == @[true, false]

  test "a cancelled refresh does not end the loading":
    service.refreshCuratedCommunities()
    started()

    finished(cancelled = true)

    check loading == @[true]

  test "a refresh reported before entering or after leaving the portal is not loading":
    started()
    service.refreshCuratedCommunities()
    service.stopCuratedCommunitiesRefresh()
    started()

    check loading.len == 0

  test "leaving the portal keeps the loading of a running refresh until it ends":
    service.refreshCuratedCommunities()
    started()

    service.stopCuratedCommunitiesRefresh()
    check loading == @[true]

    finished()
    check loading == @[true, false]

  test "the app going to the background ends the loading until it returns and a refresh starts":
    service.refreshCuratedCommunities()
    started()

    events.emit(SIGNAL_APP_BACKGROUNDED, Args())
    started()
    check loading == @[true, false]

    events.emit(SIGNAL_APP_FOREGROUNDED, Args())
    started()
    check loading == @[true, false, true]

  test "entries that failed while only placeholders are listed are a full error":
    service.onAsyncLoadCuratedCommunitiesDone(listedReply)
    service.refreshCuratedCommunities()
    started()

    finished(failed = 2)

    check errors[^1] == ord(CuratedRefreshError.Full)

  test "entries that failed next to a stored community are a partial error":
    service.onAsyncLoadCuratedCommunitiesDone(curatedReply)
    service.refreshCuratedCommunities()
    started()

    finished(failed = 1)

    check errors[^1] == ord(CuratedRefreshError.Partial)

  test "a directory that could not be read with a stored list is a partial error":
    service.refreshCuratedCommunities()
    service.onAsyncLoadCuratedCommunitiesDone(curatedReply)
    started(directoryFailed = true)

    finished()

    check errors[^1] == ord(CuratedRefreshError.Partial)

  test "a refresh that ends without a failure is no error":
    service.refreshCuratedCommunities()
    service.onAsyncLoadCuratedCommunitiesDone(curatedReply)
    started()

    finished()

    check errors.len == 0 or errors[^1] == ord(CuratedRefreshError.None)

  test "a refresh that starts clears the error":
    service.refreshCuratedCommunities()
    started()
    finished(failed = 1)
    check errors[^1] == ord(CuratedRefreshError.Full)

    started()

    check errors[^1] == ord(CuratedRefreshError.None)

  test "a cancelled refresh leaves the error as it was":
    service.refreshCuratedCommunities()
    started()
    let reported = errors.len

    finished(cancelled = true, failed = 3)

    check errors.len == reported

  test "a refresh asked for by the user while one is running is ignored":
    service.refreshCuratedCommunities()
    started()

    service.retryCuratedCommunitiesRefresh()

    check loading == @[true]

  test "a refresh that could not be asked for with nothing stored is a full error":
    service.refreshCuratedCommunities()

    check errors == @[ord(CuratedRefreshError.Full)]

  test "a refresh asked for by the user after a finished one is tried":
    service.refreshCuratedCommunities()
    started()
    finished()

    service.retryCuratedCommunitiesRefresh()

    check errors == @[ord(CuratedRefreshError.Full), ord(CuratedRefreshError.None), ord(CuratedRefreshError.Full)]

  test "returning from the background after a refresh that had finished does not start another":
    service.refreshCuratedCommunities()
    service.onAsyncLoadCuratedCommunitiesDone(curatedReply)
    started()
    finished()
    events.emit(SIGNAL_APP_BACKGROUNDED, Args())

    events.emit(SIGNAL_APP_FOREGROUNDED, Args())

    check errors == @[ord(CuratedRefreshError.Full), ord(CuratedRefreshError.None)]

  test "a refresh that found a community after leaving shows the dot until the portal opens":
    var dots: seq[bool]
    events.on(SIGNAL_CURATED_COMMUNITIES_NEW_DOT, proc(e: Args) =
      dots.add(CuratedCommunitiesNewDotArgs(e).shown))
    service.onAsyncLoadCuratedCommunitiesDone(listedReply)
    service.refreshCuratedCommunities()
    started()
    service.stopCuratedCommunitiesRefresh()
    service.onCommunityFound(fetched(unknownId))

    finished()
    check dots == @[true]

    service.refreshCuratedCommunities()
    check dots == @[true, false]

  test "a curated community that a message updates before it is found stays curated and shows the dot":
    var dots: seq[bool]
    events.on(SIGNAL_CURATED_COMMUNITIES_NEW_DOT, proc(e: Args) =
      dots.add(CuratedCommunitiesNewDotArgs(e).shown))
    service.onAsyncLoadCuratedCommunitiesDone(listedReply)
    service.refreshCuratedCommunities()
    started()
    service.stopCuratedCommunitiesRefresh()
    events.emit(SignalType.Message.event,
      MessageSignal(signalType: SignalType.Message, communities: @[fetched(featuredUnknownId)]))
    service.onCommunityFound(fetched(featuredUnknownId))

    finished()

    check service.getCommunityById(featuredUnknownId).listedInDirectory
    check service.getCommunityById(featuredUnknownId).featuredInDirectory
    check dots == @[true]

  test "a read that failed is an error even when the refresh ends without a failure":
    service.refreshCuratedCommunities()
    service.onAsyncLoadCuratedCommunitiesDone(
      """{"jsonrpc":"2.0","id":14,"error":{"code":-32000,"message":"db closed"}}""")
    started()

    finished()

    check errors[^1] == ord(CuratedRefreshError.Full)
