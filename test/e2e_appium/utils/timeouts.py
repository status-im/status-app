"""Cross-device delivery timeouts for waku-mediated messaging tests.

These constants align with the MVDS retransmit schedule and the
MissingMessageVerifier ticker observed in status-go / go-waku:

- 1st MVDS retry: ~72s + 0–9s jitter (foreground)
- 2nd MVDS retry: ~144s
- 3rd MVDS retry: ~288s
- MissingMessageVerifier ticker: 30s

The same constants apply to both Pi-local and BrowserStack environments
because both connect to the same public Status waku fleet over the
public internet (verified 2026-05-21 — mobile e2e has no
``--waku-fleet`` injection; the ``docker-compose.waku.yml`` fleet is
desktop-test infrastructure, not used by ``test/e2e_appium``).
"""

CROSS_DEVICE_DELIVERY_TIMEOUT_SECONDS = 360
"""Hard delivery deadline covering all automatic recovery paths.

Covers:
  * 1st MVDS retry (~72-81s wall-clock)
  * 2nd MVDS retry (~144-153s)
  * 3rd MVDS retry (~288-297s)
  * ~60s margin past the 3rd retry

After this, recovery requires explicit user action: restart triggers
a separate storenode history fetch that bypasses the live-delivery
chain entirely. Tests that assert eventual cross-device delivery
under nominal conditions should use this value.
"""


APP_BOOT_TIMEOUT_SECONDS = 120
"""Splash-screen budget for status-go's first-boot DB initialisation.

On Pi mid-range phones (Samsung A36, Moto G55) the splash can take
70-90s after a fresh seed-phrase import. The default 60s is too tight
there; 120s matches what the shared onboarding fixture already uses.
"""


ONBOARDING_SCREEN_TRANSITION_TIMEOUT_SECONDS = 30
"""Inter-screen navigation budget during onboarding.

The default 15s screen-displayed wait is fine for clean transitions
but too tight when status-go derives keys in the background between
seed-phrase entry and the password screen on CI/slower devices.
"""
