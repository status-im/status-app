import json
import std/strformat
import os
import uri
import chronicles
import sequtils
import nimqml

import ../settings/service as settings_service
import ../../../app/core/eventemitter
import ../../../backend/backend as status_go
import ../../../app/core/tasks/[qt, threadpool]
import ../../../app/core/[main]
import ../../../constants as main_constants
import ./dto

include ./async_tasks

logScope:
  topics = "gif-service"

const MAX_RECENT = 50

const SIGNAL_LOAD_RECENT_GIFS_STARTED* = "loadRecentGifsStarted"
const SIGNAL_LOAD_RECENT_GIFS_DONE* = "loadRecentGifsDone"

const SIGNAL_LOAD_FAVORITE_GIFS_STARTED* = "loadFavoriteGifsStarted"
const SIGNAL_LOAD_FAVORITE_GIFS_DONE* = "loadFavoriteGifsDone"

const SIGNAL_LOAD_TRENDING_GIFS_STARTED* = "loadTrendingGifsStarted"
const SIGNAL_LOAD_TRENDING_GIFS_DONE* = "loadTrendingGifsDone"
const SIGNAL_LOAD_TRENDING_GIFS_ERROR* = "loadTrendingGifsError"

const SIGNAL_SEARCH_GIFS_STARTED* = "searchGifsStarted"
const SIGNAL_SEARCH_GIFS_DONE* = "searchGifsDone"
const SIGNAL_SEARCH_GIFS_ERROR* = "searchGifsError"

type
  GifsArgs* = ref object of Args
    gifs*: seq[GifDto]
    error*: string

QtObject:
  type
    Service* = ref object of QObject
      threadpool: ThreadPool
      settingsService: settings_service.Service
      favorites: seq[GifDto]
      recents: seq[GifDto]
      trending: seq[GifDto]
      events: EventEmitter
      apiKeySet: bool

  proc delete*(self: Service) =
    discard

  proc newService*(settingsService: settings_service.Service, events: EventEmitter, threadpool: ThreadPool): Service =
    result = Service()
    result.QObject.setup
    result.settingsService = settingsService
    result.events = events
    result.threadpool = threadpool
    result.favorites = @[]
    result.recents = @[]
    result.apiKeySet = false

  proc asyncLoadRecentGifs*(self: Service) =
    self.events.emit(SIGNAL_LOAD_RECENT_GIFS_STARTED, Args())
    try:
      let arg = AsyncGetRecentGifsTaskArg(
        tptr: asyncGetRecentGifsTask,
        vptr: cast[uint](self.vptr),
        slot: "onAsyncGetRecentGifsDone"
      )
      self.threadpool.start(arg)
    except Exception as e:
      error "Error loading recent gifs", msg = e.msg

  proc onAsyncGetRecentGifsDone*(self: Service, response: string) {.slot.} =
    try:
      let rpcResponseObj = response.parseJson
      if rpcResponseObj{"error"}.kind != JNull:
        raise newException(CatchableError, rpcResponseObj{"error"}.getStr)

      self.recents = map(rpcResponseObj{"result"}.getElems(), settingToGifDto)
      self.events.emit(SIGNAL_LOAD_RECENT_GIFS_DONE, GifsArgs(gifs: self.recents))
    except Exception as e:
      error "error loading recent gifs: ", errMsg=e.msg

  proc asyncLoadFavoriteGifs*(self: Service) =
    self.events.emit(SIGNAL_LOAD_FAVORITE_GIFS_STARTED, Args())
    try:
      let arg = AsyncGetFavoriteGifsTaskArg(
        tptr: asyncGetFavoriteGifsTask,
        vptr: cast[uint](self.vptr),
        slot: "onAsyncGetFavoriteGifsDone"
      )
      self.threadpool.start(arg)
    except Exception as e:
      error "Error loading favorite gifs", msg = e.msg

  proc onAsyncGetFavoriteGifsDone*(self: Service, response: string) {.slot.} =
    try:
      let rpcResponseObj = response.parseJson
      if rpcResponseObj{"error"}.kind != JNull:
        raise newException(CatchableError, rpcResponseObj{"error"}.getStr)

      self.favorites = map(rpcResponseObj{"result"}.getElems(), settingToGifDto)
      self.events.emit(SIGNAL_LOAD_FAVORITE_GIFS_DONE, GifsArgs(gifs: self.favorites))
    except Exception as e:
      error "error loading favorite gifs", errMsg = e.msg

  proc init*(self: Service) =
    discard

  proc search*(self: Service, query: string) =
    try:
      self.events.emit(SIGNAL_SEARCH_GIFS_STARTED, Args())
      let arg = AsyncTenorQueryArg(
        tptr: asyncTenorQuery,
        vptr: cast[uint](self.vptr),
        slot: "onAsyncTenorQueryDone",
        apiKeySet: self.apiKeySet,
        apiKey: TENOR_API_KEY_RESOLVED,
        query: fmt("search?q={encodeUrl(query)}"),
        event: SIGNAL_SEARCH_GIFS_DONE,
        errorEvent: SIGNAL_SEARCH_GIFS_ERROR,
      )
      self.threadpool.start(arg)
    except Exception as e:
      error "Error getting trending gifs", msg = e.msg

  proc getTrending*(self: Service) =
    if self.trending.len > 0:
      self.events.emit(SIGNAL_LOAD_TRENDING_GIFS_DONE, GifsArgs(gifs: self.trending))
      return
    try:
      self.events.emit(SIGNAL_LOAD_TRENDING_GIFS_STARTED, Args())
      let arg = AsyncTenorQueryArg(
        tptr: asyncTenorQuery,
        vptr: cast[uint](self.vptr),
        slot: "onAsyncTenorQueryDone",
        apiKeySet: self.apiKeySet,
        apiKey: TENOR_API_KEY_RESOLVED,
        query: "trending?",
        event: SIGNAL_LOAD_TRENDING_GIFS_DONE,
        errorEvent: SIGNAL_LOAD_TRENDING_GIFS_ERROR,
      )
      self.threadpool.start(arg)
    except Exception as e:
      error "Error getting trending gifs", msg = e.msg

  proc onAsyncTenorQueryDone*(self: Service, response: string) {.slot.} =
    let rpcResponseObj = response.parseJson
    try:
      if (rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != ""):
        raise newException(RpcException, rpcResponseObj{"error"}.getStr)

      self.apiKeySet = true

      let itemsJson = rpcResponseObj["items"]

      var items: seq[GifDto] = @[]
      for itemJson in itemsJson.items:
        items.add(itemJson.settingToGifDto)

      if rpcResponseObj["event"].getStr == SIGNAL_LOAD_TRENDING_GIFS_DONE:
        # Save trending gifs in a local cache to not have to fetch them multiple times
        self.trending = items

      self.events.emit(rpcResponseObj["event"].getStr, GifsArgs(gifs: items))
    except Exception as e:
      let errMsg = e.msg
      error "Error requesting sending query to Tenor", msg = errMsg
      self.events.emit(rpcResponseObj["errorEvent"].getStr, GifsArgs(error: errMsg))

  proc getRecents*(self: Service): seq[GifDto] =
    return self.recents

  proc addToRecents*(self: Service, gifDto: GifDto) =
    let recents = self.getRecents()
    var newRecents: seq[GifDto] = @[gifDto]
    var idx = 0

    while idx < MAX_RECENT - 1:
      if idx >= recents.len:
        break

      if recents[idx].id == gifDto.id:
        idx += 1
        continue

      newRecents.add(recents[idx])
      idx += 1

    self.recents = newRecents
    let recent = %*{"items": map(newRecents, toJsonNode)}
    discard status_go.updateRecentGifs(recent)

  proc getFavorites*(self: Service): seq[GifDto] =
    return self.favorites

  proc isFavorite*(self: Service, gifDto: GifDto): bool =
    for favorite in self.favorites:
      if favorite.id == gifDto.id:
        return true
    return false

  proc toggleFavorite*(self: Service, gifDto: GifDto) =
    var newFavorites: seq[GifDto] = @[]
    var found = false

    for favoriteGif in self.getFavorites():
      if favoriteGif.id == gifDto.id:
        found = true
        continue

      newFavorites.add(favoriteGif)

    if not found:
      newFavorites.add(gifDto)

    self.favorites = newFavorites
    let favorites = %*{"items": map(newFavorites, toJsonNode)}
    discard status_go.updateFavoriteGifs(favorites)
