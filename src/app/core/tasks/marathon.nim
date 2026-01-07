import # std libs
  std/[strformat, tables]

import # vendor libs
  chronicles

import # status-desktop libs
  ./marathon/worker, ./marathon/common as marathon_common
export marathon_common

logScope:
  topics = "marathon"

type
  Marathon* = ref object
    workers: Table[string, MarathonWorker]

proc start*[T: MarathonTaskArg](self: MarathonWorker, arg: T) =
  self.chanSendToWorker.sendSync(arg.encode.safe)

proc init(self: Marathon) =
  for worker in self.workers.values:
    worker.init()

proc newMarathon*(worker: MarathonWorker): Marathon =
  new(result)
  result.workers = initTable[string, MarathonWorker]()
  result.workers[worker.name] = worker
  result.init()

proc `[]`*(self: Marathon, name: string): MarathonWorker =
  if not self.workers.contains(name):
    raise newException(ValueError, &"""Worker '{name}' is not registered. Use 'registerWorker("{name}", {name}Worker)' to register the worker first.""")
  self.workers[name]

proc teardown*(self: Marathon) =
  for worker in self.workers.values:
    worker.teardown()

proc onLoggedIn*(self: Marathon) =
  for worker in self.workers.values:
    worker.onLoggedIn()
