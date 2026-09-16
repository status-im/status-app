import pytest

from configs import get_platform
from constants import RandomUser, UserAccount
from gui.main_window import MainWindow
from helpers.community_general_helper import setup_community_general_channel
from scripts.utils.benchmark_report import enable_benchmark_mode
from tests.benchmark_tests.send_timing_helpers import run_send_timing_scenarios


@pytest.mark.skipif(get_platform() != 'Windows', reason='Windows only test')
@pytest.mark.benchmark
def test_community_general_send_message_timing(multiple_instances, tmp_path):
    enable_benchmark_mode()
    owner: UserAccount = RandomUser()
    member: UserAccount = RandomUser()
    main_window = MainWindow()

    with \
            multiple_instances(user_data=None) as aut_owner, \
            multiple_instances(user_data=None) as aut_member:
        messages_screen, wake_member_on_general = setup_community_general_channel(
            aut_owner, aut_member, main_window, owner, member,
        )
        run_send_timing_scenarios(
            tmp_path, aut_owner, messages_screen.chat, messages_screen.group_chat,
            'Community general', 'community_general',
            after_sent=wake_member_on_general,
        )
