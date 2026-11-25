import unittest, json, options

import app_service/service/accounts/dto/accounts
import app/modules/onboarding/startup_login

suite "toLoginStateDto":

  test "parses state and seq":
    let dto = toLoginStateDto(%*{"state": "inProgress", "seq": 7})
    check dto.state == LoginState.InProgress
    check dto.seq == 7'u64

  test "an unknown state reads as none, keeping the seq":
    let dto = toLoginStateDto(%*{"state": "somethingNew", "seq": 3})
    check dto.state == LoginState.None
    check dto.seq == 3'u64

  test "logged in without an account reads as none":
    check toLoginStateDto(%*{"state": "loggedIn", "seq": 2}).state == LoginState.None
    check toLoginStateDto(%*{"state": "loggedIn", "seq": 2, "account": {}}).state == LoginState.None

  test "logged in with an account":
    let dto = toLoginStateDto(%*{"state": "loggedIn", "seq": 2,
      "account": {"key-uid": "0xabc", "name": "Alice"}})
    check dto.state == LoginState.LoggedIn
    check dto.account.keyUid == "0xabc"
    check dto.seq == 2'u64

  test "no seq reads as zero":
    check toLoginStateDto(%*{"state": "none"}).seq == 0'u64

suite "toLoginSeq":

  test "reads the seq":
    check toLoginSeq(%*{"error": "", "seq": 9}) == some(9'u64)

  test "a missing seq is unknown":
    check toLoginSeq(%*{"error": ""}).isNone
    check toLoginSeq(%*{"error": "", "seq": "x"}).isNone

suite "login busy errors":

  test "only the exact rejection errors":
    check isLoginBusyError("a login is already in progress")
    check isLoginBusyError("already logged in")
    check not isLoginBusyError("")
    check not isLoginBusyError("loginAccount failed: a login is already in progress")
    check not isLoginBusyError("incorrect password provided")

suite "startup login: which node.login belongs to the UI":

  test "none: nothing requested, every node.login is ignored":
    var startup = initStartupLogin(LoginState.None, seq = 4)
    check not startup.admitNodeLogin(some(3'u64))
    check not startup.admitNodeLogin(some(4'u64))
    check not startup.admitNodeLogin(some(5'u64))

  test "only the node.login of the UI's own request is admitted, once":
    var startup = initStartupLogin(LoginState.None, seq = 4)
    startup.requestAccepted(some(6'u64))
    check not startup.admitNodeLogin(some(5'u64))
    check startup.admitNodeLogin(some(6'u64))
    check not startup.admitNodeLogin(some(6'u64))

  test "a login the UI didn't start, accepted after the read, failing while the UI's own runs, is ignored":
    var startup = initStartupLogin(LoginState.None, seq = 4)
    startup.requestAccepted(some(6'u64))
    check not startup.admitNodeLogin(some(5'u64))
    check startup.admitNodeLogin(some(6'u64))

  test "in progress: only the node.login of that login is adopted":
    var startup = initStartupLogin(LoginState.InProgress, seq = 4)
    check not startup.admitNodeLogin(some(3'u64))
    check not startup.admitNodeLogin(some(5'u64))
    check startup.admitNodeLogin(some(4'u64))
    check not startup.admitNodeLogin(some(4'u64))

  test "in progress, then that login ended: the next request's node.login counts":
    var startup = initStartupLogin(LoginState.InProgress, seq = 4)
    check startup.admitNodeLogin(some(4'u64))
    startup.requestAccepted(some(5'u64))
    check startup.admitNodeLogin(some(5'u64))

  test "logged in: the late node.login of the adopted session is ignored":
    var startup = initStartupLogin(LoginState.LoggedIn, seq = 4)
    check not startup.admitNodeLogin(some(4'u64))
    check not startup.admitNodeLogin(some(5'u64))

  test "a node.login without a seq is admitted (status-go without seqs)":
    var startup = initStartupLogin(LoginState.None, seq = 0)
    check startup.admitNodeLogin(none(uint64))

  test "a request accepted without a seq admits the next node.login":
    var startup = initStartupLogin(LoginState.None, seq = 0)
    startup.requestAccepted(none(uint64))
    check startup.admitNodeLogin(some(7'u64))
    check not startup.admitNodeLogin(some(8'u64))

  test "startup action per login state":
    check initStartupLogin(LoginState.None, 0).action == StartupAction.ShowOnboarding
    check initStartupLogin(LoginState.InProgress, 1).action == StartupAction.WaitForLogin
    check initStartupLogin(LoginState.LoggedIn, 1).action == StartupAction.AdoptSession

suite "startup login: a request rejected because another login runs":

  test "in progress: adopt that login":
    var startup = initStartupLogin(LoginState.None, seq = 4)
    check startup.adoptRunningLogin(LoginState.InProgress, seq = 5) == LoginAdoption.Adopted
    check not startup.admitNodeLogin(some(4'u64))
    check startup.admitNodeLogin(some(5'u64))

  test "logged in: adopt that login":
    var startup = initStartupLogin(LoginState.None, seq = 4)
    check startup.adoptRunningLogin(LoginState.LoggedIn, seq = 5) == LoginAdoption.Adopted
    check startup.admitNodeLogin(some(5'u64))

  test "none, after a login the UI didn't know: adopt it, its failure is pending":
    var startup = initStartupLogin(LoginState.None, seq = 4)
    check startup.adoptRunningLogin(LoginState.None, seq = 5) == LoginAdoption.Adopted
    check startup.admitNodeLogin(some(5'u64))

  test "none, nothing new: not adopted":
    var startup = initStartupLogin(LoginState.None, seq = 4)
    check startup.adoptRunningLogin(LoginState.None, seq = 4) == LoginAdoption.NotAdopted
    startup.requestAccepted(some(5'u64))
    check startup.admitNodeLogin(some(5'u64))
    check startup.adoptRunningLogin(LoginState.None, seq = 5) == LoginAdoption.NotAdopted

  test "logged in, a login whose node.login was already admitted: not adopted, nothing would arrive":
    var startup = initStartupLogin(LoginState.None, seq = 4)
    startup.requestAccepted(some(5'u64))
    check startup.admitNodeLogin(some(5'u64))
    check startup.adoptRunningLogin(LoginState.LoggedIn, seq = 5) == LoginAdoption.NotAdopted
    check startup.adoptRunningLogin(LoginState.LoggedIn, seq = 3) == LoginAdoption.NotAdopted

  test "already logged in by a login whose node.login was ignored: adopted, replayed exactly once":
    var startup = initStartupLogin(LoginState.None, seq = 4)
    check not startup.admitNodeLogin(some(5'u64))
    check startup.adoptRunningLogin(LoginState.LoggedIn, seq = 5) == LoginAdoption.AdoptedReplay
    check startup.admitNodeLogin(some(5'u64))
    check not startup.admitNodeLogin(some(5'u64))

  test "logged in, seq not newer, but its node.login was ignored: adopted with a replay":
    var startup = initStartupLogin(LoginState.None, seq = 4)
    check not startup.admitNodeLogin(some(4'u64))
    check startup.adoptRunningLogin(LoginState.LoggedIn, seq = 4) == LoginAdoption.AdoptedReplay
    check startup.admitNodeLogin(some(4'u64))

  test "a stale ignored node.login is not replayed":
    var startup = initStartupLogin(LoginState.None, seq = 4)
    check not startup.admitNodeLogin(some(3'u64))
    check startup.adoptRunningLogin(LoginState.LoggedIn, seq = 5) == LoginAdoption.Adopted
    check not startup.admitNodeLogin(some(3'u64))
    check startup.admitNodeLogin(some(5'u64))

  test "none after an ignored failed login: adopted with a replay of its failure":
    var startup = initStartupLogin(LoginState.None, seq = 4)
    check not startup.admitNodeLogin(some(5'u64))
    check startup.adoptRunningLogin(LoginState.None, seq = 5) == LoginAdoption.AdoptedReplay
    check startup.admitNodeLogin(some(5'u64))
