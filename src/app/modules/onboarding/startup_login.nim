import std/options
from app_service/service/accounts/dto/accounts import LoginState, LOGIN_IN_PROGRESS_ERROR,
  ALREADY_LOGGED_IN_ERROR

type
  StartupAction* {.pure.} = enum
    ShowOnboarding  # none: today's startup (login screen or silent "Stay logged in" login)
    WaitForLogin    # in progress: a login the UI didn't start, its node.login decides
    AdoptSession    # logged in: take the resume path

  LoginAdoption* {.pure.} = enum
    NotAdopted      # report the rejection as a login error
    Adopted         # its node.login is still to come
    AdoptedReplay   # its node.login was ignored before: replay it

  # Which node.login belongs to the UI: only the one of the login the UI requested (seq
  # from its accepted request) or adopted (seq from the login state). Seqs are per
  # status-go process.
  StartupLogin* = object
    state: LoginState             # read at startup
    knownSeq: uint64              # the latest login seq the UI knows of
    expecting: bool               # a node.login is the UI's
    expectedSeq: Option[uint64]   # none: unknown (no seq from status-go), the next one is it
    ignoredSeq: Option[uint64]    # the last node.login that wasn't the UI's
    adopted: bool                 # the expected login is one the UI didn't start

proc initStartupLogin*(state: LoginState, seq: uint64): StartupLogin =
  result = StartupLogin(state: state, knownSeq: seq)
  if state == LoginState.InProgress:
    result.expecting = true
    result.expectedSeq = some(seq)
    result.adopted = true

# The UI's login is one it adopted (most likely the boot login), not one it requested.
proc loginAdopted*(self: StartupLogin): bool =
  self.adopted

proc action*(self: StartupLogin): StartupAction =
  case self.state
  of LoginState.None: StartupAction.ShowOnboarding
  of LoginState.InProgress: StartupAction.WaitForLogin
  of LoginState.LoggedIn: StartupAction.AdoptSession

proc requestAccepted*(self: var StartupLogin, seq: Option[uint64]) =
  self.expecting = true
  self.adopted = false
  self.expectedSeq = seq
  if seq.isSome:
    self.knownSeq = max(self.knownSeq, seq.get)

# A node.login without a seq is admitted, as before seqs.
proc admitNodeLogin*(self: var StartupLogin, seq: Option[uint64]): bool =
  if seq.isNone:
    self.expecting = false
    return true
  if not self.expecting or (self.expectedSeq.isSome and self.expectedSeq.get != seq.get):
    self.ignoredSeq = seq
    return false
  self.expecting = false
  return true

proc isLoginBusyError*(error: string): bool =
  error == LOGIN_IN_PROGRESS_ERROR or error == ALREADY_LOGGED_IN_ERROR

# The UI's login request was rejected with a login busy error. Adopts the login the
# state now reports: in progress, logged in, or none after a login the UI didn't know of
# (it failed since). Its node.login decides: one still to come (a newer seq), or the
# ignored one, replayed. Anything else has no node.login to come and is not adopted.
proc adoptRunningLogin*(self: var StartupLogin, state: LoginState, seq: uint64): LoginAdoption =
  let replay = self.ignoredSeq == some(seq)
  if not replay and seq <= self.knownSeq and state != LoginState.InProgress:
    return LoginAdoption.NotAdopted
  self.knownSeq = max(self.knownSeq, seq)
  self.expecting = true
  self.expectedSeq = some(seq)
  self.adopted = true
  if replay:
    self.ignoredSeq = none(uint64)
    return LoginAdoption.AdoptedReplay
  return LoginAdoption.Adopted
