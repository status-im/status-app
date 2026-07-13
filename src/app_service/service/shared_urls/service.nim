import nimqml, json, chronicles, strutils

import ../../../backend/shared_urls as shared_urls
import ../../../app/core/eventemitter
import ../../../app/core/tasks/threadpool

import ./dto/url_data as url_data_dto

export url_data_dto

logScope:
  topics = "shared-urls-app-service"

QtObject:
  type Service* = ref object of QObject
    events: EventEmitter
    threadpool: ThreadPool

  proc extractResultError(payload: JsonNode): string =
    if payload.kind == JObject and payload.contains("error"):
      return payload["error"].getStr()
    return ""
  
  proc newService*(events: EventEmitter, threadpool: ThreadPool): Service =
    result = Service()
    result.QObject.setup
    result.events = events

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
