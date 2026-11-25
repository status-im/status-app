## After a login, only the stay-logged-in task writes or removes the boot-login record.
## A login that queues no such task must remove it, so a boot login never resumes the
## previous login's profile.

import unittest

import app/modules/onboarding/post_onboarding/task

suite "loginDecidesBootLoginRecord":

  test "a password or keycard login queues the stay-logged-in task, which decides the record":
    check loginDecidesBootLoginRecord(@[PostOnboardingTask(kind: kPostOnboardingTaskSaveStayLoggedIn)])

  test "a recovery-phrase login queues no task":
    check not loginDecidesBootLoginRecord(newSeq[PostOnboardingTask]())

  test "onboarding without the opt-in queues only other tasks":
    check not loginDecidesBootLoginRecord(@[PostOnboardingTask(kind: kPostOnboardingTaskSaveBiometrics),
      PostOnboardingTask(kind: kPostOnboardingTaskLocalBackup)])

suite "bootLoginRecordAfterLogin":

  test "the UI's own login with the stay-logged-in task: the task decides":
    check bootLoginRecordAfterLogin(@[PostOnboardingTask(kind: kPostOnboardingTaskSaveStayLoggedIn)],
      loginAdopted = false) == BootLoginRecordAfterLogin.DecidedByTasks

  test "the UI's own login without it: removed":
    check bootLoginRecordAfterLogin(newSeq[PostOnboardingTask](), loginAdopted = false) ==
      BootLoginRecordAfterLogin.Removed

  test "an adopted login (the boot login) queues no task: its record is kept current":
    check bootLoginRecordAfterLogin(newSeq[PostOnboardingTask](), loginAdopted = true) ==
      BootLoginRecordAfterLogin.KeptCurrent
