import std/[options, sequtils]

from app_service/service/accounts/dto/accounts import AccountDto

proc zeroOnboardingBlockedBy*(flagEnabled, testEnvironment, coldStart: bool,
    profileCount: Option[int]): string =
  ## Why the app may not create a zero-onboarded profile, or "" when it may.
  ## Test runs drive the Welcome screen from an empty data dir, so they never do.
  if not flagEnabled:
    return "feature flag off"
  if testEnvironment:
    return "test mode"
  if not coldStart:
    return "not at process start"
  if profileCount.isNone:
    return "profiles could not be listed"
  if profileCount.get > 0:
    return "a profile exists"
  ""

proc listedOnLoginScreen*(accounts: seq[AccountDto]): seq[AccountDto] =
  accounts.filterIt(not it.zeroOnboarded)

proc zeroOnboardedKeyUid*(accounts: seq[AccountDto]): string =
  ## The newest, should there ever be more than one.
  var newest = int64.low
  for account in accounts:
    if account.zeroOnboarded and account.timestamp >= newest:
      newest = account.timestamp
      result = account.keyUid
