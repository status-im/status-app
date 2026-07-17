"""Shared helpers for desktop benchmark e2e tests."""

import pytest

import configs
import constants
from constants.wallet import WalletNetworkSettings
from fixtures.aut import FRESH_USER_ACCOUNT

BENCHMARK_USER_PARAMS = dict(indirect=['user_data', 'user_account'])

WALLET_BENCHMARK_PARAMS = [
    pytest.param(None, FRESH_USER_ACCOUNT, id='fresh_user'),
    pytest.param(configs.testpath.TEST_USER_DATA / 'wallet_load', constants.user.wallet_load, id='wallet_load_user'),
    pytest.param(
        configs.testpath.TEST_USER_DATA / 'wallet_load_alex', constants.user.wallet_load_alex,
        id='wallet_load_alex_user',
    ),
]

WALLET_ACCOUNT_BENCHMARK_PARAMS = [
    pytest.param(
        None,
        FRESH_USER_ACCOUNT,
        WalletNetworkSettings.STATUS_ACCOUNT_DEFAULT_NAME.value,
        id='fresh_user',
    ),
    pytest.param(
        configs.testpath.TEST_USER_DATA / 'wallet_load',
        constants.user.wallet_load,
        'firstaccount',
        id='wallet_load_user',
    ),
    pytest.param(
        configs.testpath.TEST_USER_DATA / 'wallet_load_alex',
        constants.user.wallet_load_alex,
        'account1',
        id='wallet_load_alex_user',
    ),
]

COMMUNITY_MEMBER_BENCHMARK_PARAMS = [
    pytest.param(
        configs.testpath.TEST_USER_DATA / 'status_community_member',
        constants.user.status_community_member,
        id='user_data0-user_account0',
    ),
]
