type CountRefreshCompletionAction* = enum
  crcaApply
  crcaDropAndRefire

type CountRefreshGenerationState* = object
  desiredGeneration: int
  inFlightState: bool
  inFlightGeneration: int

proc initCountRefreshGenerationState*(): CountRefreshGenerationState =
  CountRefreshGenerationState()

proc inFlight*(self: CountRefreshGenerationState): bool =
  self.inFlightState

proc currentGeneration*(self: CountRefreshGenerationState): int =
  self.inFlightGeneration

proc requestRefresh*(self: var CountRefreshGenerationState): tuple[shouldStart: bool, generation: int] =
  inc self.desiredGeneration
  if self.inFlightState:
    return (shouldStart: false, generation: self.desiredGeneration)

  self.inFlightState = true
  self.inFlightGeneration = self.desiredGeneration
  return (shouldStart: true, generation: self.desiredGeneration)

proc onCompletion*(
    self: var CountRefreshGenerationState,
    completedGeneration: int,
    ): tuple[action: CountRefreshCompletionAction, generation: int] =
  if completedGeneration < self.desiredGeneration:
    self.inFlightState = true
    self.inFlightGeneration = self.desiredGeneration
    return (action: crcaDropAndRefire, generation: self.desiredGeneration)

  self.inFlightState = false
  return (action: crcaApply, generation: completedGeneration)