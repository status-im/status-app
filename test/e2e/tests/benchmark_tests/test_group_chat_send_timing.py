import pytest

from configs import get_platform
from constants import RandomUser, UserAccount
from gui.main_window import MainWindow
from helpers.group_chat_helper import setup_three_user_group_chat
from scripts.utils.benchmark_report import enable_benchmark_mode
from tests.benchmark_tests.send_timing_helpers import run_send_timing_scenarios


@pytest.mark.skipif(get_platform() != 'Windows', reason='Windows only test')
@pytest.mark.benchmark
def test_group_chat_send_message_timing(multiple_instances, tmp_path):
    enable_benchmark_mode()
    user_one: UserAccount = RandomUser()
    user_two: UserAccount = RandomUser()
    user_three: UserAccount = RandomUser()
    main_window = MainWindow()

    with \
            multiple_instances(user_data=None) as aut_one, \
            multiple_instances(user_data=None) as aut_two, \
            multiple_instances(user_data=None) as aut_three:
        messages_screen = setup_three_user_group_chat(
            aut_one, aut_two, aut_three, main_window, user_one, user_two, user_three,
        )
        run_send_timing_scenarios(
            tmp_path, aut_one, messages_screen.chat, messages_screen.group_chat,
            'Group chat', 'group_chat',
        )
