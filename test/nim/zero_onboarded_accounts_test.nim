import unittest, options

import app_service/service/accounts/dto/accounts
import app/modules/onboarding/zero_onboarded_accounts

proc account(keyUid: string, zeroOnboarded = false, timestamp = 0'i64): AccountDto =
  AccountDto(name: keyUid, keyUid: keyUid, zeroOnboarded: zeroOnboarded, timestamp: timestamp)

suite "zero-onboarded accounts":

  test "the zero-onboarded profile is left out of the login list":
    let accounts = @[account("uid_1"), account("uid_zero", zeroOnboarded = true), account("uid_2")]
    check accounts.listedOnLoginScreen().len == 2
    check "uid_zero" notin accounts.listedOnLoginScreen()
    check accounts.zeroOnboardedKeyUid() == "uid_zero"

  test "no zero-onboarded profile":
    let accounts = @[account("uid_1")]
    check accounts.listedOnLoginScreen().len == 1
    check accounts.zeroOnboardedKeyUid() == ""

  # Should never happen (status-go creates one only on an empty device)
  test "the newest of several zero-onboarded profiles is used":
    let accounts = @[account("uid_old", true, timestamp = 10), account("uid_new", true, timestamp = 20)]
    check accounts.zeroOnboardedKeyUid() == "uid_new"
    check accounts.listedOnLoginScreen().len == 0

suite "zero-onboarding allowed":

  test "a first start without profiles zero-onboards":
    check zeroOnboardingBlockedBy(flagEnabled = true, testEnvironment = false, coldStart = true,
      profileCount = some(0)) == ""

  test "each rule blocks it on its own":
    check zeroOnboardingBlockedBy(flagEnabled = false, testEnvironment = false, coldStart = true,
      profileCount = some(0)) == "feature flag off"
    check zeroOnboardingBlockedBy(flagEnabled = true, testEnvironment = true, coldStart = true,
      profileCount = some(0)) == "test mode"
    check zeroOnboardingBlockedBy(flagEnabled = true, testEnvironment = false, coldStart = false,
      profileCount = some(0)) == "not at process start"
    check zeroOnboardingBlockedBy(flagEnabled = true, testEnvironment = false, coldStart = true,
      profileCount = none(int)) == "profiles could not be listed"
    check zeroOnboardingBlockedBy(flagEnabled = true, testEnvironment = false, coldStart = true,
      profileCount = some(1)) == "a profile exists"

suite "removing zero-onboarded profiles":

  let accounts = @[
    account("uid_regular"),
    account("uid_zero", zeroOnboarded = true, timestamp = 200),
    account("uid_zero_old", zeroOnboarded = true, timestamp = 100)]

  test "the zero-onboarded profiles are listed by key UID":
    check accounts.zeroOnboardedKeyUids() == @["uid_zero", "uid_zero_old"]

  # The list is the one seen at load: nothing is fetched once logged in
  test "a regular login removes every zero-onboarded profile":
    check zeroOnboardedToRemoveOnLogin(accounts.zeroOnboardedKeyUids(), "uid_regular") ==
      @["uid_zero", "uid_zero_old"]

  test "opening the zero-onboarded profile removes only the others":
    check zeroOnboardedToRemoveOnLogin(accounts.zeroOnboardedKeyUids(), "uid_zero") == @["uid_zero_old"]

  test "at start, once a regular profile reached the main app, every zero-onboarded profile goes":
    check zeroOnboardedToRemoveAtStart(accounts, mainAppKeyUid = "uid_regular") ==
      @["uid_zero", "uid_zero_old"]

  test "at start, otherwise only the newest zero-onboarded profile stays":
    check zeroOnboardedToRemoveAtStart(accounts, mainAppKeyUid = "uid_zero") == @["uid_zero_old"]
    check zeroOnboardedToRemoveAtStart(accounts, mainAppKeyUid = "") == @["uid_zero_old"]

  test "a regular profile that never reached the main app keeps the zero-onboarded one":
    check zeroOnboardedToRemoveAtStart(accounts, mainAppKeyUid = "uid_gone") == @["uid_zero_old"]

  test "nothing to remove without zero-onboarded profiles":
    check zeroOnboardedToRemoveOnLogin(@[account("uid_regular")].zeroOnboardedKeyUids(), "uid_regular").len == 0
    check zeroOnboardedToRemoveAtStart(@[account("uid_regular")], "uid_regular").len == 0
