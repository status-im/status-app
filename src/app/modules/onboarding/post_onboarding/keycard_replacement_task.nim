import task

import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/keycardV2/service as keycard_serviceV2

export task

type KeycardReplacementTask* = ref object of PostOnboardingTask
  keyUid: string
  keycardInstanceUID: string

proc newKeycardReplacementTask*(keyUid: string,
                                keycardInstanceUID: string): KeycardReplacementTask =
  result = KeycardReplacementTask(
    kind: kPostOnboardingTaskKeycardReplacement,
    keyUid: keyUid,
    keycardInstanceUID: keycardInstanceUID,
  )

proc run*(self: KeycardReplacementTask,
            walletAccountService: wallet_account_service.Service,
            keycardServiceV2: keycard_serviceV2.Service) =

  # TODO: not needed for the new keycard approach
  discard