import std/json
import chronicles
import task
import ../io_interface

import app/global/global_singleton
import app_service/service/accounts/service as accounts_service
import app_service/common/keychain_credential
import app_service/common/utils as common_utils

export task

type StayLoggedInAction* {.pure.} = enum
  FollowStored # keep the stored preference: re-store the credential only when it is ON
  Enable # the user opted in (onboarding checkbox, or the login-screen toggle turned ON)
  Disable # the user turned the login-screen toggle OFF

proc stayLoggedInActionFromLoginData*(data: JsonNode): StayLoggedInAction =
  ## The login screen sends "stayLoggedIn" only when the user changed the toggle.
  ## Only an explicit JSON bool is a choice: a missing key, null or any other type
  ## follows the stored preference, so malformed input can never delete a credential.
  let choice = data{"stayLoggedIn"}
  if choice.isNil or choice.kind != JBool: StayLoggedInAction.FollowStored
  elif choice.getBool: StayLoggedInAction.Enable
  else: StayLoggedInAction.Disable

type SaveStayLoggedInTask* = ref object of PostOnboardingTask
  credential*: string # raw password, or the raw DEK hex — disambiguated by credentialIsDek
  # True ONLY when constructed by the trusted DEK login branch. NEVER inferred from the
  # credential's content: a legitimate password could begin with "dek:" and must still go
  # through conversion like any other password.
  credentialIsDek*: bool
  keyUid*: string # empty only for onboarding flows, when the profile is created during the flow
  action*: StayLoggedInAction

proc newSaveStayLoggedInPasswordTask*(password: string, keyUid: string = "",
    action = StayLoggedInAction.FollowStored): SaveStayLoggedInTask =
  result = SaveStayLoggedInTask(
      kind: kPostOnboardingTaskSaveStayLoggedIn,
      credential: password,
      credentialIsDek: false,
      keyUid: keyUid,
      action: action,
    )

proc newSaveStayLoggedInDekTask*(dek: string, keyUid: string = "",
    action = StayLoggedInAction.FollowStored): SaveStayLoggedInTask =
  result = SaveStayLoggedInTask(
      kind: kPostOnboardingTaskSaveStayLoggedIn,
      credential: dek,
      credentialIsDek: true,
      keyUid: keyUid,
      action: action,
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
    debug "keycard profile — requesting stay-logged-in reconciliation only"
    onboardingModule.requestSaveStayLoggedIn(loggedInAccount.keyUid, "", false, "")
    return

  # The user turned the toggle OFF on the login screen: delete the credential (the QML
  # handler turns the preference OFF only after a verified delete), then send the empty
  # save request so the handler lifts any auto-login suppression. No DEK export.
  # The empty save request also retries the delete, but that retry never turns the
  # preference OFF, even when it succeeds: if the first delete was not verified, the
  # preference stays ON and the next login re-stores the credential.
  if self.action == StayLoggedInAction.Disable:
    onboardingModule.requestDeleteStayLoggedIn(loggedInAccount.keyUid)
    onboardingModule.requestSaveStayLoggedIn(loggedInAccount.keyUid, "", false, "")
    return

  let enable = self.action == StayLoggedInAction.Enable

  # With the preference OFF (and no opt-in), there is nothing to store: skip
  # the DEK export entirely (two synchronous status-go calls on the GUI thread, and the
  # raw DEK would cross into the QML/JS heap only to be discarded). The request is still
  # emitted — with an empty credential — so the QML handler can lift any auto-login
  # suppression and reconcile away a stale credential.
  if not enable and not singletonInstance.localAccountSettings.getStayLoggedIn():
    onboardingModule.requestSaveStayLoggedIn(loggedInAccount.keyUid, "", false, "")
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
  # The boot-login record follows the credential: written next to it, empty (removed)
  # whenever no credential is stored.
  onboardingModule.requestSaveStayLoggedIn(loggedInAccount.keyUid, toStore, enable,
    accountsService.bootLoginRecord(loggedInAccount.keyUid))
