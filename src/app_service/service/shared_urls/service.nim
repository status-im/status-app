import nimqml, json, chronicles, strutils, tables, sets

import ../../../backend/shared_urls as shared_urls
import ../../../backend/accounts as status_accounts
import ../../../app/core/eventemitter
import ../../../app/core/tasks/[qt, threadpool]
import ../../../app/global/feature_flags
from ../../common/conversion import isCompressedPubKey

import ./dto/url_data as url_data_dto

export url_data_dto

logScope:
  topics = "shared-urls-app-service"

include async_tasks

const
  SIGNAL_PROFILE_URLS_RESOLVED* = "profileUrlsResolved"
  ProfileUrlCacheCapacity = 512
  ProfileUrlBatchSize = 32
  ProfileUrlPendingCapacity = 128

type ProfileUrlsResolvedArgs* = ref object of Args
  profilesJson*: string

QtObject:
  type Service* = ref object of QObject
    events: EventEmitter
    threadpool: ThreadPool
    profileUrlCache: OrderedTable[string, JsonNode]
    # Reference counts for unresolved URLs still requested by message delegates.
    pendingProfileUrls: OrderedTable[string, int]
    resolvingProfileUrls: seq[string]

  proc extractResultError(payload: JsonNode): string =
    if payload.kind == JObject and payload.contains("error"):
      return payload["error"].getStr()
    return ""
  
  proc delete*(self: Service)

  proc newService*(events: EventEmitter, threadpool: ThreadPool): Service =
    new(result, delete)
    result.QObject.setup
    result.events = events
    result.threadpool = threadpool

  proc startProfileUrlBatch(self: Service) =
    if not THREADPOOL_ENABLED or self.threadpool.isNil or
        self.resolvingProfileUrls.len > 0 or self.pendingProfileUrls.len == 0:
      return

    for url in self.pendingProfileUrls.keys:
      self.resolvingProfileUrls.add(url)
      if self.resolvingProfileUrls.len == ProfileUrlBatchSize:
        break
    self.threadpool.start(ResolveProfileUrlsTaskArg(
      tptr: resolveProfileUrlsTask,
      vptr: cast[uint](self.vptr),
      slot: "onProfileUrlsResolved",
      urls: self.resolvingProfileUrls))

  iterator requestedProfileUrls(urlsJson: string): string =
    let urls = try: parseJson(urlsJson)
      except JsonParsingError: newJNull()
    if urls.kind == JArray:
      var seen: HashSet[string]
      for entry in urls:
        let url = entry.getStr()
        if url.len > 0 and not seen.containsOrIncl(url):
          yield url

  proc resolveProfileUrls*(self: Service, urlsJson: string): string =
    # Return cache hits immediately and coalesce misses across message delegates.
    var cached = newJObject()
    for url in requestedProfileUrls(urlsJson):
      if self.profileUrlCache.hasKey(url):
        cached[url] = self.profileUrlCache[url]
      elif not THREADPOOL_ENABLED or self.threadpool.isNil:
        cached[url] = newJNull()
      elif self.pendingProfileUrls.hasKey(url) or self.pendingProfileUrls.len < ProfileUrlPendingCapacity:
        inc self.pendingProfileUrls.mgetOrPut(url, 0)
      else:
        # Tell the caller to retry when a batch completes and frees capacity.
        cached[url] = %false
    self.startProfileUrlBatch()
    return $cached

  proc releaseProfileUrls*(self: Service, urlsJson: string) =
    for url in requestedProfileUrls(urlsJson):
      let subscribers = self.pendingProfileUrls.getOrDefault(url)
      if subscribers > 1:
        self.pendingProfileUrls[url] = subscribers - 1
      elif subscribers == 1:
        self.pendingProfileUrls.del(url)

  proc onProfileUrlsResolved*(self: Service, profilesJson: string) {.slot.} =
    let profiles = parseJson(profilesJson)
    var completed = newJObject()
    for url in self.resolvingProfileUrls:
      let requested = self.pendingProfileUrls.hasKey(url)
      self.pendingProfileUrls.del(url)
      if not profiles.hasKey(url):
        if requested:
          completed[url] = newJNull()
        continue
      if self.profileUrlCache.len >= ProfileUrlCacheCapacity:
        let oldest = block:
          var key: string
          for cachedUrl in self.profileUrlCache.keys:
            key = cachedUrl
            break
          key
        self.profileUrlCache.del(oldest)
      self.profileUrlCache[url] = profiles[url]
      if requested:
        completed[url] = profiles[url]
    self.resolvingProfileUrls.setLen(0)
    self.events.emit(SIGNAL_PROFILE_URLS_RESOLVED, ProfileUrlsResolvedArgs(profilesJson: $completed))
    self.startProfileUrlBatch()

  proc delete*(self: Service) =
    self.QObject.delete

  proc parseSharedUrl*(self: Service, url: string): UrlDataDto =
    try:
      let response = shared_urls.parseSharedUrl(url)
      let errMsg = extractResultError(response.result)
      if errMsg != "":
        raise newException(Exception, errMsg)
      # not a status shared url
      return response.result.toUrlDataDto()
    except Exception as e:
      if not e.msg.contains("not a status shared url"):
        error "failed to parse shared url: ", url, errDesription = e.msg
      result.notASupportedStatusLink = true

  proc createMessageUrl*(self: Service, chatId: string, messageId: string): string =
    try:
      let response = shared_urls.shareMessageUrl(chatId, messageId)
      let errMsg = extractResultError(response.result)
      if errMsg != "":
        raise newException(Exception, errMsg)
      return response.result.getStr()
    except Exception as e:
      error "failed to create message url", chatId, messageId, errDescription = e.msg
      return ""

  proc parseMessageUrl*(self: Service, url: string): MessageUrlDataDto =
    try:
      let response = shared_urls.parseMessageUrl(url)
      let errMsg = extractResultError(response.result)
      if errMsg != "":
        raise newException(Exception, errMsg)
      return response.result.toMessageUrlDataDto()
    except Exception as e:
      if not e.msg.contains("not a status message url"):
        error "failed to parse message url", url, errDescription = e.msg

  proc createThreadUrl*(self: Service, chatId: string, threadId: string): string =
    try:
      let response = shared_urls.shareThreadUrl(chatId, threadId)
      let errMsg = extractResultError(response.result)
      if errMsg != "":
        raise newException(Exception, errMsg)
      return response.result.getStr()
    except Exception:
      error "failed to create thread url"
      return ""

  proc parseThreadUrl*(self: Service, url: string): ThreadUrlDataDto =
    try:
      let response = shared_urls.parseThreadUrl(url)
      let errMsg = extractResultError(response.result)
      if errMsg != "":
        raise newException(Exception, errMsg)
      return response.result.toThreadUrlDataDto()
    except Exception:
      error "failed to parse thread url"
