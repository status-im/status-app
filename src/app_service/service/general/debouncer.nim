import nimqml, os

import universal_container
import app/core/tasks/[qt, threadpool]


include app_service/common/async_tasks

QtObject:
  type Debouncer* = ref object of QObject
    threadpool: ThreadPool
    callback0: proc()
    callback1Wrapper: proc()
    callback2Wrapper: proc()
    delay: int
    checkInterval: int
    remaining: int

    params: Container


  proc delete*(self: Debouncer)
  proc newDebouncer*(threadpool: ThreadPool, delayMs: int, checkIntervalMs: int): Debouncer =
    new(result, delete)
    result.QObject.setup
    if checkIntervalMs > delayMs:
      raise newException(ValueError, "checkIntervalMs must be less than delayMs")
    result.threadpool = threadpool
    result.delay = delayMs
    result.checkInterval = checkIntervalMs
    result.params = newContainer()

  proc registerCall0*(self: Debouncer, callback: proc()) =
    self.callback0 = callback

  proc registerCall1*[T1](self: Debouncer, callback: proc(p1: T1)) =
    self.callback1Wrapper = proc() =
      let param0 = getValueAtPosition[T1](self.params, 0)
      callback(param0)

  proc registerCall2*[T1, T2](self: Debouncer, callback: proc(p1: T1, p2: T2)) =
    self.callback2Wrapper = proc() =
      let param0 = getValueAtPosition[T1](self.params, 0)
      let param1 = getValueAtPosition[T2](self.params, 1)
      callback(param0, param1)

  proc runTimer*(self: Debouncer) =
    let arg = TimerTaskArg(
      tptr: timerTask,
      vptr: cast[uint](self.vptr),
      slot: "onTimeout",
      timeoutInMilliseconds: self.checkInterval
    )
    self.threadpool.start(arg)

  proc onTimeout(self: Debouncer, response: string) {.slot.} =
    self.remaining = self.remaining - self.checkInterval
    if self.remaining <= 0:
      if not self.callback0.isNil:
        self.callback0()
      elif not self.callback1Wrapper.isNil:
        self.callback1Wrapper()
      elif not self.callback2Wrapper.isNil:
        self.callback2Wrapper()
    else:
      self.runTimer()

  proc call*(self: Debouncer) =
    let busy = self.remaining > 0
    if busy:
      return
    self.params.clear()
    self.remaining = self.delay
    self.runTimer()

  proc call*[T1](self: Debouncer, param0: T1) =
    let busy = self.remaining > 0
    if busy:
      return
    self.params.clear()
    self.params.add(param0)
    self.remaining = self.delay
    self.runTimer()

  proc delete*(self: Debouncer) =
    self.QObject.delete