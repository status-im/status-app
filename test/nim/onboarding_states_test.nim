import unittest

import app/modules/onboarding/states

suite "OnboardingFlow fresh profile classification":

  test "only profile creation flows create fresh profiles":
    for flow in OnboardingFlow:
      case flow:
      of OnboardingFlow.CreateProfileWithPassword,
         OnboardingFlow.CreateProfileWithSeedphrase,
         OnboardingFlow.CreateProfileWithKeycardNewSeedphrase,
         OnboardingFlow.CreateProfileWithKeycardExistingSeedphrase:
        check flow.createsFreshProfile()
      else:
        check not flow.createsFreshProfile()