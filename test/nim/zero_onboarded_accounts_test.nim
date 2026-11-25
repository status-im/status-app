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
