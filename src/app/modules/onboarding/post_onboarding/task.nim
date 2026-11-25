import std/sequtils

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

# The tasks that save a credential typed for a login (biometrics, "Stay logged in").
proc withoutCredentialTasks*(tasks: seq[PostOnboardingTask]): seq[PostOnboardingTask] =
  for task in tasks:
    if task.kind != kPostOnboardingTaskSaveBiometrics and task.kind != kPostOnboardingTaskSaveStayLoggedIn:
      result.add(task)

# The post-login tasks of the current login flow. A flow whose login request was rejected
# and replaced by an adopted login is abandoned: none of its work runs, including the
# tasks it would queue after the rejection.
type PostLoginTasks* = object
  tasks: seq[PostOnboardingTask]
  abandoned: bool

proc newPostLoginTasks*(): PostLoginTasks =
  PostLoginTasks()

proc tasks*(self: PostLoginTasks): seq[PostOnboardingTask] =
  self.tasks

proc startFlow*(self: var PostLoginTasks) =
  self.tasks = @[]
  self.abandoned = false

# A new login request: a credential queued by a previous (failed) attempt is never saved.
proc retryLogin*(self: var PostLoginTasks) =
  self.tasks = self.tasks.withoutCredentialTasks()
  self.abandoned = false

proc abandon*(self: var PostLoginTasks) =
  self.tasks = @[]
  self.abandoned = true

proc add*(self: var PostLoginTasks, task: PostOnboardingTask) =
  if not self.abandoned:
    self.tasks.add(task)

proc loginDecidesBootLoginRecord*(tasks: openArray[PostOnboardingTask]): bool =
  ## Only the stay-logged-in task writes or removes the boot-login record. After a
  ## login without it (recovery phrase, onboarding without the opt-in) the record must
  ## be removed, so a boot login never resumes the previous login's profile.
  tasks.anyIt(it.kind == kPostOnboardingTaskSaveStayLoggedIn)

type BootLoginRecordAfterLogin* {.pure.} = enum
  DecidedByTasks  # the stay-logged-in task writes or removes it
  Removed
  KeptCurrent     # rewritten as in a resumed session

proc bootLoginRecordAfterLogin*(tasks: openArray[PostOnboardingTask], loginAdopted: bool): BootLoginRecordAfterLogin =
  ## An adopted login (most likely the boot login) runs none of the UI's post-login
  ## tasks, yet its record must stay for the next phone restart: kept current under the
  ## resumed-session rule.
  if loginAdopted:
    BootLoginRecordAfterLogin.KeptCurrent
  elif loginDecidesBootLoginRecord(tasks):
    BootLoginRecordAfterLogin.DecidedByTasks
  else:
    BootLoginRecordAfterLogin.Removed
