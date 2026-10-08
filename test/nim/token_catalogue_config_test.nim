import std/[json, unittest]
import ../../src/app_service/service/accounts/dto/wallet_config

suite "token catalogue login configuration":
  test "zero-value DTO preserves explicit false flags":
    let payload = WalletConfig().toJson()
    check payload["tokenListsUseNim"].getBool() == false
    check payload["tokenListsShadow"].getBool() == false

  test "selected flags retain their backend wire names":
    let config = WalletConfig(tokenListsUseNim: true, tokenListsShadow: true)
    let payload = config.toJson()
    check payload["tokenListsUseNim"].getBool()
    check payload["tokenListsShadow"].getBool()

  test "explicit false provides rollback in the same wire format":
    let payload = WalletConfig(
      tokenListsUseNim: false, tokenListsShadow: false).toJson()
    check not payload["tokenListsUseNim"].getBool()
    check not payload["tokenListsShadow"].getBool()
