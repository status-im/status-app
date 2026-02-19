"""iOS onboarding integration test.

Runs the full onboarding fixture on iOS and verifies that the wallet
landing screen appears.  This exercises cross-platform locators, text
input, gestures, and page navigation end-to-end.

Prerequisites
-------------
An iOS ``.ipa`` build must be uploaded to BrowserStack.  Set
``BROWSERSTACK_APP_ID`` to the IPA's ``bs://`` URL or ``shareable_id``.

Running
-------
::

    # Upload an iOS .ipa to BrowserStack, then:
    export BROWSERSTACK_APP_ID="bs://<ios_ipa_hash>"

    TEST_DEVICE_ID=ipad_10th_gen_ios_16 \\
    python -m pytest tests/test_ios_poc.py::TestIOSOnboarding -v --env=browserstack -n 0 \\
      -o "addopts=-v --tb=short --strict-markers --timeout=600 --reruns 0 --dist=loadscope"
"""

import pytest

from pages.base_page import BasePage
from utils.multi_device_helpers import StepMixin
from utils.platform import get_platform


@pytest.mark.ios
@pytest.mark.smoke
@pytest.mark.device_count(1)
class TestIOSOnboarding(StepMixin):
    """Run the full onboarding fixture on iOS and verify wallet landing.

    This test does **not** use ``raw_devices`` — it exercises the
    ``OnboardingFlow`` fixture end-to-end, which covers:

    1. Welcome screen → Create Profile
    2. Analytics screen → Skip
    3. Create Profile → Let's go
    4. Password screen → enter + confirm password
    5. Biometrics → dismiss
    6. Loading / splash screen → wait for completion
    7. Wallet landing → verify ADD_ACCOUNT_BUTTON visible
    """

    async def test_ios_onboarding_flow(self):
        """Verify onboarding completes and wallet landing is reached on iOS."""
        base = BasePage(self.device.driver)

        async with self.step(self.device, "Report platform and user info"):
            platform = get_platform(self.device.driver)
            user = self.device.user
            self.logger.info(
                "Platform: %s | User: %s | Onboarded: %s",
                platform,
                user.display_name if user else "N/A",
                user is not None,
            )
            assert user is not None, (
                "Onboarding fixture should have created a user"
            )

        async with self.step(self.device, "Dump wallet landing page source"):
            base.dump_page_source("ios_onboarding_wallet_landing")

        async with self.step(self.device, "Verify wallet landing screen"):
            from locators.wallet.accounts_locators import WalletAccountsLocators
            visible = base.is_element_visible(
                WalletAccountsLocators.ADD_ACCOUNT_BUTTON, timeout=15
            )
            assert visible, (
                "Wallet ADD_ACCOUNT_BUTTON should be visible after onboarding"
            )
