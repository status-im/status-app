import nimqml, json, chronicles, times
include ../../common/json_utils
import ../../../app/core/tasks/[qt, threadpool]
import ../../../app/global/global_singleton

import backend/response_type
import status_go
import constants
import ./dto

proc getIsCentralizedMetricsEnabled*(): bool =
  try:
    let response = status_go.centralizedMetricsInfo()
    let jsonObj = response.parseJson
    if jsonObj.hasKey("error"):
      error "isCentralizedMetricsEnabled", errorMsg=jsonObj["error"].getStr
      return false
    let metricsInfo = toCentralizedMetricsInfoDto(jsonObj)
    return metricsInfo.enabled
  except Exception:
    return false

include async_tasks

logScope:
  topics = "metrics"

QtObject:
  type MetricsService* = ref object of QObject
    threadpool: ThreadPool
    metricsEnabled: bool

  proc delete*(self: MetricsService)
  proc newService*(threadpool: ThreadPool): MetricsService =
    new(result, delete)
    result.QObject.setup
    result.threadpool = threadpool

    signalConnect(singletonInstance.globalEvents, "addCentralizedMetricIfEnabled(QString, QString)",
      result, "addCentralizedMetricIfEnabled(QString, QString)", 2)

  proc addCentralizedMetricIfEnabled*(self: MetricsService, eventName: string, eventValueJson: string) {.slot.} =
    # Disabled for now. Will be completely removed in 2.38
    discard

  proc onCentralizedMetricAddedIdEnabled*(self: MetricsService, response: string) {.slot.} =
    try:
      let responseObj = response.parseJson
      let errorString = responseObj{"error"}.getStr()
      if errorString != "":
        error "onCentralizedMetricAddedIdEnabled", error=errorString
        return
      
      if responseObj{"metricsDisabled"}.getBool:
        return

      debug "onCentralizedMetricAddedIdEnabled", metricId=responseObj{"metricId"}.getStr()
    except Exception as e:
      error "onCentralizedMetricAddedIdEnabled", exceptionMsg = e.msg

  proc centralizedMetricsEnabledChanged*(self: MetricsService) {.signal.}
  proc isCentralizedMetricsEnabled*(self: MetricsService): bool {.slot.} =
    return getIsCentralizedMetricsEnabled()

  QtProperty[bool] isCentralizedMetricsEnabled:
    read = isCentralizedMetricsEnabled
    notify = centralizedMetricsEnabledChanged

  proc toggleCentralizedMetrics*(self: MetricsService, enabled: bool) {.slot.} =
    try:
      let isEnabled = self.isCentralizedMetricsEnabled()
      if enabled == isEnabled:
        return
      let payload = %* {"enabled": enabled}
      let response = status_go.toggleCentralizedMetrics($payload)
      let jsonObj = response.parseJson
      if jsonObj{"error"}.getStr.len > 0:
        error "toggleCentralizedMetrics", errorMsg=jsonObj["error"].getStr
      else:
        self.centralizedMetricsEnabledChanged()
    except Exception as e:
      error "toggleCentralizedMetrics", exceptionMsg = e.msg

  proc delete*(self: MetricsService) =
    self.QObject.delete

