# NOTE: Keep in sync with OnboardingFlow in ui/StatusQ/src/onboarding/enums.h
type OnboardingFlow* {.pure} = enum
  Unknown = 0,

  CreateProfileWithPassword,
  CreateProfileWithSeedphrase,
  CreateProfileWithKeycardNewSeedphrase,
  CreateProfileWithKeycardExistingSeedphrase,

  LoginWithSeedphrase,
  LoginWithSyncing,
  LoginWithKeycard,
  LoginWithLostKeycardSeedphrase,
  LoginWithRestoredKeycard,

  OnboardingLoginWithKeycard,
  OnboardingImportNewKeyPair,
  OnboardingImportSeedPhrase

proc createsFreshProfile*(flow: OnboardingFlow): bool =
  case flow:
  of OnboardingFlow.CreateProfileWithPassword,
     OnboardingFlow.CreateProfileWithSeedphrase,
     OnboardingFlow.CreateProfileWithKeycardNewSeedphrase,
     OnboardingFlow.CreateProfileWithKeycardExistingSeedphrase:
    true
  else:
    false

type LoginMethod* {.pure} = enum
  Unknown = 0,
  Password,
  Keycard,
  Mnemonic,

type ProgressState* {.pure.} = enum
  Idle,
  InProgress,
  Success,
  Failed,
