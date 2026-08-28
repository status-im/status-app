import task
import chronicles
import ../io_interface

export task

import app_service/service/accounts/service as accounts_service

type KeycardConvertAccountTask* = ref object of PostOnboardingTask
  keyUid: string
  mnemonic: string
  newPassword*: string

proc newKeycardConvertAccountTask*(keyUid: string,
                                   mnemonic: string,
                                   newPassword: string): KeycardConvertAccountTask =
  result = KeycardConvertAccountTask(
    kind: kConvertKeycardAccountToRegular,
    keyUid: keyUid,
    mnemonic: mnemonic,
    newPassword: newPassword,
  )

proc run*(self: KeycardConvertAccountTask,
          accountsService: accounts_service.Service,
          onboardingModule: AccessInterface) =

  debug "running post-onboarding kConvertKeycardAccountToRegular"

  # Remove PIN from Keychain for this account, as it won't be a valid database password after re-encryption.
  # If needed, the new password will be saved as part of SaveBiometricsTask.
  onboardingModule.requestDeleteBiometrics(self.keyUid)

  # The conversion re-encrypts the profile: the silently stored DEK becomes stale, and
  # the resulting keycard-history profile is out of scope for "Stay logged in" anyway —
  # remove the credential and (on verified deletion, QML-side) turn the preference off.
  onboardingModule.requestDeleteStayLoggedIn(self.keyUid)

  # TODO: Implement V2 endpoint in status-go which automatically calculates current password
  let account = accountsService.createAccountFromMnemonic(self.mnemonic, includeEncryption = true)
  let currentPassword = account.derivedAccounts.encryption.publicKey

  accountsService.convertKeycardProfileKeypairToRegular(
      self.mnemonic,
      currentPassword,
      self.newPassword)
