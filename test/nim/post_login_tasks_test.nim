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

  test "an adopted login abandons the flow: nothing the flow queues afterwards is kept":
    var queue = newPostLoginTasks()
    queue.startFlow()
    queue.add(taskOf(kConvertKeycardAccountToRegular))
    queue.retryLogin()
    # the login request is rejected and the running login adopted
    queue.abandon()
    # the onboarding flow finishes after the rejection
    queue.add(taskOf(kPostOnboardingTaskSaveBiometrics))
    queue.add(taskOf(kPostOnboardingTaskSaveStayLoggedIn))
    queue.add(taskOf(kPostOnboardingTaskLocalBackup))
    check queue.tasks.len == 0

  test "a flow whose login request is accepted keeps its tasks, in order":
    var queue = newPostLoginTasks()
    queue.startFlow()
    queue.add(taskOf(kConvertKeycardAccountToRegular))
    queue.retryLogin()
    queue.add(taskOf(kPostOnboardingTaskSaveBiometrics))
    queue.add(taskOf(kPostOnboardingTaskSaveStayLoggedIn))
    queue.add(taskOf(kPostOnboardingTaskLocalBackup))
    check queue.tasks.len == 4
    check queue.tasks[0].kind == kConvertKeycardAccountToRegular
    check queue.tasks[3].kind == kPostOnboardingTaskLocalBackup

  test "a new login request after an abandoned flow queues again, without the old credentials":
    var queue = newPostLoginTasks()
    queue.startFlow()
    queue.add(taskOf(kPostOnboardingTaskSaveBiometrics))
    queue.abandon()
    queue.retryLogin()
    queue.add(taskOf(kPostOnboardingTaskSaveStayLoggedIn))
    check queue.tasks.len == 1
    check queue.tasks[0].kind == kPostOnboardingTaskSaveStayLoggedIn

  test "a login retry drops the credential tasks of the failed attempt, keeps the rest":
    var queue = newPostLoginTasks()
    queue.startFlow()
    queue.add(taskOf(kConvertKeycardAccountToRegular))
    queue.add(taskOf(kPostOnboardingTaskSaveBiometrics))
    queue.retryLogin()
    check queue.tasks.len == 1
    check queue.tasks[0].kind == kConvertKeycardAccountToRegular
