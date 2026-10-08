import std/[json, unittest]
import ../../src/app_service/service/accounts/dto/[wallet_config, login_request,
  create_account_request]

suite "token catalogue login configuration":
  test "login and account creation use the sole backend without selectors":
    let config = WalletConfig(
      tokensListsAutoRefreshInterval: 3600,
      tokensListsAutoRefreshCheckInterval: 60)
    for payload in [LoginAccountRequest(walletConfig: config).toJson(),
        CreateAccountRequest(walletConfig: config).toJson()]:
      check not payload.hasKey("tokenListsUseNim")
      check not payload.hasKey("tokenListsShadow")
      check payload["tokensListsAutoRefreshInterval"].getInt() == 3600
      check payload["tokensListsAutoRefreshCheckInterval"].getInt() == 60
