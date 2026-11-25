import unittest, json

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

suite "startup login: which node.login belongs to the UI":

  test "none: a stale node.login of a login the UI didn't start is ignored":
    var startup = initStartupLogin(LoginState.None, seq = 4)
    check not startup.admitNodeLogin(3)
    check not startup.admitNodeLogin(4)

  test "none: the node.login of a later login is the UI's":
    var startup = initStartupLogin(LoginState.None, seq = 4)
    check startup.admitNodeLogin(5)
    check startup.admitNodeLogin(6)

  test "in progress: only the node.login of that login is adopted":
    var startup = initStartupLogin(LoginState.InProgress, seq = 4)
    check not startup.admitNodeLogin(3)
    check startup.admitNodeLogin(4)

  test "in progress, then that login ended: only later logins count":
    var startup = initStartupLogin(LoginState.InProgress, seq = 4)
    check startup.admitNodeLogin(4)
    check not startup.admitNodeLogin(4)
    check startup.admitNodeLogin(5)

  test "logged in: the late node.login of the adopted session is ignored":
    var startup = initStartupLogin(LoginState.LoggedIn, seq = 4)
    check not startup.admitNodeLogin(4)
    check startup.admitNodeLogin(5)

  test "startup action per login state":
    check initStartupLogin(LoginState.None, 0).action == StartupAction.ShowOnboarding
    check initStartupLogin(LoginState.InProgress, 1).action == StartupAction.WaitForLogin
    check initStartupLogin(LoginState.LoggedIn, 1).action == StartupAction.AdoptSession
