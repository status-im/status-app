import allure
import pytest
from allure_commons._allure import step

import configs
import driver
from constants import DEFAULT_PIN, KEYCARD_EMPTY_TITLE, RandomCommunity, RandomUser, UserAccount
from gui.components.changes_detected_popup import ChangesDetectedToastMessage
from gui.keycard_simulator_controller import KeycardSimulatorController
from gui.main_window import MainWindow
from helpers.chat_helper import skip_message_backup_popup_if_visible
from helpers.multiple_instances_helper import (
    accept_contact_request_from_settings,
    authorize_user_in_aut,
    get_chat_key,
    send_contact_request_from_settings,
    switch_to_aut,
)
from helpers.onboarding_helper import (
    open_create_profile_view,
    skip_post_login_popups_if_visible,
    wait_until_logged_in,
)
from scripts.utils.generators import keycard_card_id, random_text_message


@pytest.mark.keycard
@pytest.mark.timeout(500)
@allure.title('Sign community join request with Keycard (shared addresses)')
@allure.description(
    'Owner password profile creates an open community and invites a Keycard profile. '
    'Invitee shares all addresses, signs the join request with PIN, then Join is hidden '
    'and owner sees invitee in the community members list.'
)
def test_sign_community_join_shared_addresses_on_keycard(multiple_instances):
    owner: UserAccount = RandomUser()
    invitee: UserAccount = RandomUser()
    community = RandomCommunity()
    main_screen = MainWindow()
    card_id = keycard_card_id()

    with multiple_instances() as aut_owner, multiple_instances() as aut_invitee:
        with step(f'Owner {owner.name}: create password profile'):
            authorize_user_in_aut(aut_owner, main_screen, owner)

        with step(f'Invitee {invitee.name}: create profile on empty Keycard'):
            switch_to_aut(aut_invitee, main_screen)
            keycard_simulator = (
                KeycardSimulatorController(app_window=main_screen).wait_until_appears().start_simulator()
            )
            keycard_simulator.create_empty_card(card_id=card_id)
            keycard_simulator.plug_reader()
            keycard_mng_popup = open_create_profile_view().open_create_profile_with_keycard()
            keycard_simulator.select_card(card_id).insert_card()
            keycard_dtls_view = keycard_mng_popup.enter_keycard_pin(pin=DEFAULT_PIN)
            assert keycard_dtls_view.keycard_view_title.text == KEYCARD_EMPTY_TITLE

            keycard_mng_popup = keycard_dtls_view.import_a_new_keypair()
            keycard_mng_popup.enter_new_pin_and_confirm(pin=DEFAULT_PIN)
            keycard_mng_popup.reveal_recovery_phrase()
            seed_words = keycard_mng_popup.write_down_recovery_phrase()
            keycard_mng_popup.open_confirm_recovery_phrase().fill_the_grid_and_continue(seed_words)
            keycard_mng_popup.continue_after_key_pair_imported()
            wait_until_logged_in(main_screen)
            skip_post_login_popups_if_visible()

            profile = main_screen.left_panel.open_settings().left_panel.open_profile_settings()
            profile.set_name(invitee.name)
            ChangesDetectedToastMessage().save_changes()
            main_screen.minimize()

        with step(f'{invitee.name} shares chat key'):
            chat_key = get_chat_key(aut_invitee, main_screen)
            main_screen.minimize()

        with step(f'{owner.name} sends contact request to {invitee.name}'):
            send_contact_request_from_settings(
                aut_owner, main_screen, chat_key, f'Hello {invitee.name}')
            main_screen.minimize()

        with step(f'{invitee.name} accepts contact from {owner.name}'):
            accept_contact_request_from_settings(aut_invitee, main_screen, owner.name)

        with step(f'{owner.name} creates community and invites {invitee.name}'):
            switch_to_aut(aut_owner, main_screen)
            main_screen.left_panel.create_community(community_data=community)
            community_screen = main_screen.left_panel.open_community(community.name)
            add_members = community_screen.left_panel.open_add_members_popup()
            add_members.invite([invitee.name], message=random_text_message())
            main_screen.minimize()

        with step(f'{invitee.name} joins community and signs shared addresses with Keycard PIN'):
            switch_to_aut(aut_invitee, main_screen)
            keycard_simulator.plug_reader()
            keycard_simulator.select_card(card_id).insert_card()

            messages_view = main_screen.left_panel.open_messages_screen()
            skip_message_backup_popup_if_visible()
            assert driver.waitFor(
                lambda: owner.name in messages_view.left_panel.get_chats_names,
                configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
            ), f'Chat with {owner.name} not in list'
            chat = messages_view.left_panel.click_chat_by_name(owner.name)
            community_screen = chat.click_community_invite_message()
            welcome_popup = community_screen.left_panel.open_welcome_community_popup()
            assert community.name in welcome_popup.title
            assert community.introduction == welcome_popup.intro
            welcome_popup.share_all_and_sign()
            welcome_popup.sign_all_with_pin(DEFAULT_PIN)
            welcome_popup.submit_shared_addresses()
            assert driver.waitFor(
                lambda: not community_screen.left_panel.is_join_community_visible,
                configs.timeouts.APP_LOAD_TIMEOUT_MSEC,
            ), 'Join community button not hidden'

        with step(f'{owner.name} sees {invitee.name} in community members list'):
            switch_to_aut(aut_owner, main_screen)
            community_screen = main_screen.left_panel.open_community(community.name)
            assert driver.waitFor(
                lambda: invitee.name in community_screen.right_panel.members,
                configs.timeouts.LOADING_LIST_TIMEOUT_MSEC,
            ), f'{invitee.name} should appear in community members after Keycard join'
            assert driver.waitFor(
                lambda: '2' in community_screen.left_panel.members,
                configs.timeouts.LOADING_LIST_TIMEOUT_MSEC,
            ), 'Community should show 2 members (owner + invitee)'
