import logging
import os
import time

import pytest
import allure
from allure_commons.types import AttachmentType
from allure_commons._allure import step

import configs
from configs import get_platform
import constants

import driver
from gui.screens.wallet import WalletScreen

LOG = logging.getLogger(__name__)


def record_assets_loading_time(
    wallet_left_panel,
    account_name: str,
    timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
) -> float:
    """Select the given account and return time until the assets list is populated."""
    start_time = time.time()
    wallet_account_view = wallet_left_panel.select_account(account_name)
    asset_item = wallet_account_view._asset_item  # pylint: disable=protected-access

    check_interval = 0.1  # seconds
    timeout_sec = timeout_msec / 1000

    while time.time() - start_time < timeout_sec:
        try:
            token_list_items = driver.findAllObjects(asset_item.real_name)
            if token_list_items:
                LOG.info(
                    "Assets list for %s visible with %d items",
                    account_name,
                    len(token_list_items),
                )
                break
        except Exception as e:  # noqa: BLE001
            LOG.debug("Exception during assets visibility check: %s", e)
        time.sleep(check_interval)
    else:
        load_time = time.time() - start_time
        LOG.error(
            "Assets list for %s not visible within %d ms (waited %.3f seconds)",
            account_name,
            timeout_msec,
            load_time,
        )
        raise TimeoutError(
            f"Assets list for {account_name} is not visible within {timeout_msec} ms"
        )

    load_time = time.time() - start_time
    LOG.info("Assets for %s loaded in %.3f seconds", account_name, load_time)
    return load_time


@pytest.mark.parametrize(
    "user_data, user_account, first_account_name, second_account_name",
    [
        pytest.param(
            configs.testpath.TEST_USER_DATA / "wallet_load",
            constants.user.wallet_load,
            "firstaccount",
            "secondaccount",
            id="wallet_load_user",
        ),
        pytest.param(
            configs.testpath.TEST_USER_DATA / "wallet_load_alex",
            constants.user.wallet_load_alex,
            "account1",
            "account2",
            id="wallet_load_alex_user",
        ),
    ],
)
@pytest.mark.skipif(get_platform() != "Windows", reason="Windows only test")
def test_wallet_assets_loading_time(
    main_screen, user_data, user_account, first_account_name, second_account_name, tmp_path
):
    os.environ["STATUS_RUNTIME_TEST_MODE"] = "True"  # to omit banners

    with step("Open wallet main screen"):
        main_screen.left_panel.open_wallet()

    wallet_left_panel = WalletScreen().left_panel
    firstaccount_times = []
    secondaccount_times = []
    report_lines = []

    for i in range(5):
        with step(f"Iteration {i + 1}: Open {first_account_name} and record assets load time"):
            t1 = record_assets_loading_time(wallet_left_panel, first_account_name)
            firstaccount_times.append(t1)
            line = f"[{i + 1}/5] {first_account_name} assets load time: {t1:.3f} seconds"
            report_lines.append(line)
            print(line)
            LOG.info(line)

        with step(f"Iteration {i + 1}: Open {second_account_name} and record assets load time"):
            t2 = record_assets_loading_time(wallet_left_panel, second_account_name)
            secondaccount_times.append(t2)
            line = f"[{i + 1}/5] {second_account_name} assets load time: {t2:.3f} seconds"
            report_lines.append(line)
            print(line)
            LOG.info(line)

    avg_first = sum(firstaccount_times) / len(firstaccount_times) if firstaccount_times else 0.0
    avg_second = sum(secondaccount_times) / len(secondaccount_times) if secondaccount_times else 0.0
    report_lines.append("")
    report_lines.append(f"Average {first_account_name} assets load time over 5 runs: {avg_first:.3f} seconds")
    report_lines.append(f"Average {second_account_name} assets load time over 5 runs: {avg_second:.3f} seconds")
    report_text = "\n".join(report_lines)
    print(report_text)
    LOG.info(report_text)

    report_file = tmp_path / "wallet_assets_load_times.txt"
    report_file.write_text(report_text, encoding="utf-8")

    with step("Attach wallet assets load times to Allure"):
        allure.attach(
            report_text,
            name="Wallet assets load times (text)",
            attachment_type=AttachmentType.TEXT,
        )
        allure.attach.file(
            str(report_file),
            name="Wallet assets load times (file)",
            attachment_type=AttachmentType.TEXT,
        )

