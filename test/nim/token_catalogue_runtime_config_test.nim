import std/[json, os, strutils]
import ../../src/constants
import ../../src/app_service/service/accounts/dto/[wallet_config, login_request,
  create_account_request]

# Build and run CLI/environment cases with make tests-nim-token-catalogue.
# This uses the repository's Qt/pkg-config environment and is part of tests-nim.
# Do not use unittest here: it treats CLI configuration flags as test filters
# and can silently skip assertions in precisely the rollback case being tested.
let
  config = WalletConfig(
    tokenListsUseNim: TOKEN_LISTS_USE_NIM,
    tokenListsShadow: TOKEN_LISTS_SHADOW)
  expectedNim = parseBool(getEnv("TKL_TEST_EXPECT_NIM", "true"))
  expectedShadow = parseBool(getEnv("TKL_TEST_EXPECT_SHADOW", "false"))
for payload in [LoginAccountRequest(walletConfig: config).toJson(),
    CreateAccountRequest(walletConfig: config).toJson()]:
  doAssert payload["tokenListsUseNim"].getBool() == expectedNim
  doAssert payload["tokenListsShadow"].getBool() == expectedShadow
echo "Token catalogue runtime and wire flags verified"
