import chronicles
import task
import ../io_interface

import app_service/service/accounts/service as accounts_service
import app_service/common/keychain_credential

export task

type SaveBiometricsTask* = ref object of PostOnboardingTask
  credential*: string
  isPin*: bool
  keyUid*: string # empty only for onboarding flows, when the profile is created during the flow

proc newSaveBiometricsTask*(credential: string, isPin: bool = false, keyUid: string = ""): SaveBiometricsTask =
  result = SaveBiometricsTask(
      kind: kPostOnboardingTaskSaveBiometrics,
      credential: credential,
      isPin: isPin,
      keyUid: keyUid,
    )

proc run*(self: SaveBiometricsTask, accountsService: accounts_service.Service, onboardingModule: AccessInterface) =
  debug "running post-onboarding SaveBiometricsTask"

  let loggedInKeyUid = accountsService.getLoggedInAccount().keyUid
  if self.keyUid.len > 0 and self.keyUid != loggedInKeyUid:
    warn "skipping biometric save, the logged-in account does not match the task's account"
    return

  var toStore = self.credential
  if not self.isPin:
    # Password profiles store the wrapped DEK when the profile is DEK-migrated, the raw password otherwise.
    # Keycard profiles (isPin) store the PIN.
    toStore = biometricCredentialForPasswordProfile(loggedInKeyUid, self.credential)
  if toStore.len == 0:
    error "failed to prepare biometric credential, biometrics will not be enabled"
    return
  onboardingModule.requestSaveBiometrics(loggedInKeyUid, toStore)
