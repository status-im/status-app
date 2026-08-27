type PostOnboardingTaskKind* = enum
  # NOTE: Call from Login page when the keycard was lost and is being replaced.
  kPostOnboardingTaskKeycardReplacement = 0

  # NOTE: This syncs the list of wallets between the app and the keycard.
  kPostOnboardingSyncKeycardWallets = 1 # Onboarding V1 name: syncKeycardBasedOnAppWalletState

  # NOTE: Do when restoring same keycard from recovery phrase.
  #       In theory this means that the old UID will never be used again, as it is being destroyed on the same physical keycard. # TODO: But do we really need to bother?
  #       Comparing to the `KeycardReplacementTask` which is used when the keycard is lost and a new one is being used. Theoretically the old keycard can still be found and used. # WARNING: But is this secure?
  kPostOnboardingUpdateKeycardUid = 2 # Onboarding V1 name: changedKeycardUids

  # This task is scheduled if the user agreed to use biometrics.
  kPostOnboardingTaskSaveBiometrics = 3

  # This task is scheduled in LoginWithLostKeycardSeedphrase to convert the keycard account to a regular account.
  kConvertKeycardAccountToRegular = 4

  # This task is scheduled if the user provided a local backup file URL during onboarding.
  kPostOnboardingTaskLocalBackup = 5

  # This task stores (or reconciles) the silently readable "Stay logged in" credential
  # after a successful login.
  kPostOnboardingTaskSaveStayLoggedIn = 6

type PostOnboardingTask* = ref object of RootObj
  kind*: PostOnboardingTaskKind

# NOTE: In theory we could define a `run` {.base.} method here.
# But for now there are not many task kinds, and they require different arguments.

proc kind*(self: PostOnboardingTask): PostOnboardingTaskKind =
  return self.kind
