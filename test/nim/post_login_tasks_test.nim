import unittest

import app/modules/onboarding/post_onboarding/task

proc taskOf(kind: PostOnboardingTaskKind): PostOnboardingTask =
  PostOnboardingTask(kind: kind)

suite "post-login tasks":

  test "dropping the credential tasks keeps every other task, in order":
    let tasks = @[
      taskOf(kPostOnboardingTaskKeycardReplacement),
      taskOf(kPostOnboardingTaskSaveBiometrics),
      taskOf(kPostOnboardingTaskLocalBackup),
      taskOf(kPostOnboardingTaskSaveStayLoggedIn),
      taskOf(kConvertKeycardAccountToRegular),
    ]
    let kept = tasks.withoutCredentialTasks()
    check kept.len == 3
    check kept[0].kind == kPostOnboardingTaskKeycardReplacement
    check kept[1].kind == kPostOnboardingTaskLocalBackup
    check kept[2].kind == kConvertKeycardAccountToRegular
