from app_service/service/accounts/dto/accounts import LoginState

type
  StartupAction* {.pure.} = enum
    ShowOnboarding  # none: today's startup (login screen or silent "Stay logged in" login)
    WaitForLogin    # in progress: a login the UI didn't start, its node.login decides
    AdoptSession    # logged in: take the resume path

  # The login state the onboarding module read at startup. Its seq tells the UI's own
  # node.login from a queued one of a login the UI didn't start.
  StartupLogin* = object
    state: LoginState
    seq: uint64

proc initStartupLogin*(state: LoginState, seq: uint64): StartupLogin =
  StartupLogin(state: state, seq: seq)

proc action*(self: StartupLogin): StartupAction =
  case self.state
  of LoginState.None: StartupAction.ShowOnboarding
  of LoginState.InProgress: StartupAction.WaitForLogin
  of LoginState.LoggedIn: StartupAction.AdoptSession

# Whether a node.login belongs to the UI. In progress: only that login's node.login,
# which ends the wait. Otherwise only a login after the one read at startup.
proc admitNodeLogin*(self: var StartupLogin, seq: uint64): bool =
  if self.state == LoginState.InProgress:
    if seq != self.seq:
      return false
    self.state = LoginState.None
    return true
  return seq > self.seq
