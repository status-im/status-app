import chronicles, strutils
import task
import ../io_interface

import app_service/service/accounts/service as accounts_service
import app_service/common/keychain_credential
import app_service/common/utils as common_utils

export task

type SaveStayLoggedInTask* = ref object of PostOnboardingTask
  credential*: string # raw password, or the raw DEK hex — disambiguated by credentialIsDek
  # True ONLY when constructed by the trusted DEK login branch. NEVER inferred from the
  # credential's content: a legitimate password could begin with "dek:" and must still go
  # through conversion like any other password.
  credentialIsDek*: bool
  keyUid*: string # empty only for onboarding flows, when the profile is created during the flow
  enablePreference*: bool # true only for the onboarding-checkbox flow (new user opted in)

proc newSaveStayLoggedInPasswordTask*(password: string, keyUid: string = "", enablePreference: bool = false): SaveStayLoggedInTask =
  result = SaveStayLoggedInTask(
      kind: kPostOnboardingTaskSaveStayLoggedIn,
      credential: password,
      credentialIsDek: false,
      keyUid: keyUid,
      enablePreference: enablePreference,
    )

proc newSaveStayLoggedInDekTask*(dek: string, keyUid: string = "", enablePreference: bool = false): SaveStayLoggedInTask =
  result = SaveStayLoggedInTask(
      kind: kPostOnboardingTaskSaveStayLoggedIn,
      credential: dek,
      credentialIsDek: true,
      keyUid: keyUid,
      enablePreference: enablePreference,
    )

proc run*(self: SaveStayLoggedInTask, accountsService: accounts_service.Service, onboardingModule: AccessInterface) =
  debug "running post-onboarding SaveStayLoggedInTask"

  let loggedInAccount = accountsService.getLoggedInAccount()
  if self.keyUid.len > 0 and self.keyUid != loggedInAccount.keyUid:
    warn "skipping stay-logged-in save, the logged-in account does not match the task's account"
    return

  # Keycard profiles are out of scope for "Stay logged in": a silently readable DEK would
  # bypass the hardware factor the user deliberately chose.
  if loggedInAccount.keycardPairing.len > 0:
    debug "skipping stay-logged-in save for a keycard profile"
    return

  var toStore: string
  if self.credentialIsDek:
    toStore = DEK_CREDENTIAL_PREFIX & self.credential
  else:
    # Password input is ALWAYS converted, regardless of its text (see credentialIsDek),
    # through the conversion that structurally cannot return a password: it yields a
    # tagged DEK only for a confirmed-migrated profile with a successful export, and ""
    # otherwise — so even a legacy password shaped exactly like a tagged DEK can never
    # reach the silent store.
    toStore = dekCredentialForPasswordProfile(loggedInAccount.keyUid, self.credential)

  if toStore.len == 0:
    debug "profile not DEK-migrated, stay-logged-in credential not stored"
    return

  # Defense-in-depth shape check on top of the provenance guarantees above; never the
  # primary authorization.
  if not common_utils.isTaggedDekCredential(toStore):
    warn "stay-logged-in credential has an invalid DEK shape, not stored"
    return
  onboardingModule.requestSaveStayLoggedIn(loggedInAccount.keyUid, toStore, self.enablePreference)
