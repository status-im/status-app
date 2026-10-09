"""Community delivered regression (SDS ACK path via member follow-up message)."""

import pytest
from allure_commons._allure import step

from constants import RandomUser, UserAccount
from constants.links import external_link
from gui.main_window import MainWindow
from helpers.community_general_helper import setup_community_general_channel
from scripts.utils.generators import random_text_message
from tests.benchmark_tests.send_timing_helpers import GIF_URL, complete_community_outgoing_delivery


@pytest.mark.communities
def test_community_general_delivered_after_member_ack(multiple_instances):
    """SDS ACK for text, a GIF and a link."""
    owner: UserAccount = RandomUser()
    member: UserAccount = RandomUser()
    main_window = MainWindow()

    with \
            multiple_instances(user_data=None) as aut_owner, \
            multiple_instances(user_data=None) as aut_member:
        messages_screen, wake_member_on_general = setup_community_general_channel(
            aut_owner, aut_member, main_window, owner, member,
        )
        chat = messages_screen.chat
        group_chat = messages_screen.group_chat

        payload = random_text_message()
        with step('Text: visible → sent → member ACK → delivered'):
            complete_community_outgoing_delivery(
                chat,
                wake_member_on_general,
                lambda: group_chat.send_message_to_group_chat(payload),
                message_text=payload,
            )

        with step('GIF: visible → sent → member ACK → delivered'):
            complete_community_outgoing_delivery(
                chat,
                wake_member_on_general,
                lambda: group_chat.send_gif_to_chat(GIF_URL),
                message_text=GIF_URL,
            )

        def send_link():
            group_chat.type_message(external_link)
            group_chat.confirm_sending_message()

        with step('Link: visible → sent → member ACK → delivered'):
            complete_community_outgoing_delivery(
                chat,
                wake_member_on_general,
                send_link,
                message_text=external_link,
            )
