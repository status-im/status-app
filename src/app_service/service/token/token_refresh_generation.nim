## Pure generation coordinator for the token service's heavy async tasks:
## refresh-tokens and fetch-all-token-lists.
##
## Without coalescing, each queued trigger starts its own task and every
## completion applies. This coordinator gives one task kind a generation:
##  - each trigger bumps the desired generation;
##  - a task is started only when none is in flight;
##  - the in-flight completion re-fires once if newer triggers arrived while it
##    ran, and its own (now stale) result is dropped without applying.
## Net: N queued triggers -> exactly one apply of the newest data. Pure, so it is
## unit-tested without a live Service; the service owns the actual task start/apply.

type RefreshCompletionAction* = enum
  rcaApply          ## the completed result is the newest — apply it
  rcaDropAndRefire  ## the completed result is stale — drop it and start a fresh task

type RefreshGenerationState* = object
  desiredGen: int   ## bumped on every trigger; the newest generation wanted
  inFlightState: bool
  inFlightGen: int  ## the generation the currently-running task was started with

proc initRefreshGenerationState*(): RefreshGenerationState =
  RefreshGenerationState(desiredGen: 0, inFlightState: false, inFlightGen: 0)

proc inFlight*(self: RefreshGenerationState): bool =
  self.inFlightState

proc currentGeneration*(self: RefreshGenerationState): int =
  ## The generation of the task currently in flight. Callers pass this to
  ## onCompletion when a completion cannot be decoded (so it is treated as the
  ## in-flight generation, not an always-stale sentinel — which would re-fire
  ## forever on a persistently undecodable response).
  self.inFlightGen

proc requestRefresh*(self: var RefreshGenerationState): tuple[shouldStart: bool, gen: int] =
  ## Called on a trigger. Advances the desired generation. Returns shouldStart=true
  ## (with the generation to stamp the task) only when no task is in flight; when
  ## one is already running it returns false — that task will re-fire on completion.
  inc self.desiredGen
  if self.inFlightState:
    return (shouldStart: false, gen: self.desiredGen)
  self.inFlightState = true
  self.inFlightGen = self.desiredGen
  return (shouldStart: true, gen: self.desiredGen)

proc onCompletion*(self: var RefreshGenerationState,
    completedGen: int): tuple[action: RefreshCompletionAction, gen: int] =
  ## Called when a task completes. If newer triggers arrived while it ran, its
  ## result is stale: drop it and re-fire once with the newest generation.
  ## Otherwise it is the newest: apply it and go idle.
  if completedGen < self.desiredGen:
    self.inFlightState = true
    self.inFlightGen = self.desiredGen
    return (action: rcaDropAndRefire, gen: self.desiredGen)
  self.inFlightState = false
  return (action: rcaApply, gen: completedGen)
