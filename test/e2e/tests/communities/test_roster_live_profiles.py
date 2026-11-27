"""Roster display data stays right and live for every member (#22945, PR #23354).

Tester is a plain member whose roster is checked; Bob owns the community and is everyone's
mutual contact, so he can invite them. Plan IDs refer to the "E2E test plan — #22945 live
roster profiles" doc. PH-01..PH-03 and THR-01 are expected to fail on master.
"""
import os
import random
import re
import string
import time
import typing

import pytest
from allure_commons._allure import step

import configs
import driver
from constants import RandomCommunity, UserAccount
from gui.components.changes_detected_popup import ChangesDetectedToastMessage
from gui.components.remove_contact_popup import RemoveContactPopup
from gui.main_window import MainWindow
from gui.screens.community import MembersListPanel
from gui.screens.community_settings import CommunitySettingsScreen, MembersView
from gui.screens.messages import MessagesScreen
from gui.screens.messages.threads import ChatInfoThreads, open_thread_from_message
from helpers.community_general_helper import join_community_from_invite
from helpers.multiple_instances_helper import (
    add_mutual_contact_via_activity_center,
    authorize_user_in_aut,
    get_chat_key,
    get_user_display_name,
    send_contact_request_from_settings,
    switch_to_aut,
)
from scripts.utils.generators import random_password_string, random_text_message

LIVE_MSEC = configs.timeouts.MESSAGING_TIMEOUT_SEC * 1000
# The roster is an idle-released held resource (DefaultIdleReleaseMs = 120 s).
IDLE_RELEASE_SEC = 130
GENERATED_ALIAS = re.compile(r'[A-Z][a-z]+ [A-Z][a-z]+ [A-Z][a-z]+')
THREADS_ENABLED = os.environ.get('FLAG_THREADS_ENABLED') == '1'


def _suffix() -> str:
    return ''.join(random.choices(string.ascii_lowercase, k=6))


def _user(prefix: str, set_display_name: bool = True) -> UserAccount:
    # Lowercase letters only, so the expected order does not depend on case folding rules.
    return UserAccount(name=f'{prefix}{_suffix()}', password=random_password_string(),
                       set_display_name=set_display_name)


def _shown(row: dict) -> str:
    return row['nickname'] or row['name']


def _row(rows: typing.List[dict], name: str) -> typing.Optional[dict]:
    return next((r for r in rows if name in (r['name'], r['nickname'])), None)


def _canonical(rows: typing.List[dict]) -> bool:
    keys = [(not r['online'], _shown(r).casefold()) for r in rows]
    return keys == sorted(keys)


def _assert_canonical(rows: typing.List[dict]):
    assert _canonical(rows), f'Rows are not online-first then alphabetical: {rows}'


def _assert_no_generated_alias(names: typing.Iterable[str], allowed: typing.Iterable[str] = ()):
    allowed = set(allowed)
    aliases = [n for n in names if n not in allowed and GENERATED_ALIAS.fullmatch(n)]
    assert not aliases, f'Generated three-word names shown for members with a display name: {aliases}'


def _assert_alphabetical(names: typing.List[str], members: typing.Iterable[str]):
    listed = [n for n in names if n in set(members)]
    assert listed == sorted(listed, key=str.casefold), f'Mention suggestions not alphabetical: {names}'


def _wait_rows(predicate, message: str, timeout_msec: int = LIVE_MSEC) -> typing.List[dict]:
    panel = MembersListPanel()
    seen: typing.List[dict] = []
    errors: typing.List[str] = []

    def check():
        try:
            seen[:] = panel.member_rows
        except Exception as error:
            errors[:] = [repr(error)]
            return False
        return predicate(seen)

    assert driver.wait_until(check, timeout_msec), f'{message}; rows: {seen}; last error: {errors}'
    return list(seen)


def _wait_names(expected: typing.Iterable[str], timeout_msec: int = LIVE_MSEC) -> typing.List[dict]:
    expected = set(expected)
    return _wait_rows(lambda rows: {_shown(r) for r in rows} == expected,
                      f'Members panel should show exactly {sorted(expected)}', timeout_msec)


def _wait_mentions(read, expected: typing.Iterable[str], timeout_msec: int = LIVE_MSEC) -> typing.List[str]:
    expected = set(expected)
    seen: typing.List[str] = []
    errors: typing.List[str] = []

    def check():
        try:
            seen[:] = read()
        except Exception as error:
            errors[:] = [repr(error)]
            return False
        return expected <= set(seen)

    assert driver.wait_until(check, timeout_msec), f'@mention list should include {sorted(expected)}; got {seen}; last error: {errors}'
    return list(seen)


def _open_community(main_screen, community):
    return main_screen.left_panel.open_community(community.name)


def _post(main_screen, community, text: str = None):
    # From community settings the community's own view does not load; start from Messages.
    main_screen.left_panel.open_messages_screen()
    _open_community(main_screen, community)
    MessagesScreen().group_chat.send_message_to_group_chat(text or random_text_message())


def _rename(main_screen, community, new_name: str):
    """A profile change travels with the member's identity, so post afterwards."""
    profile = main_screen.left_panel.open_settings().left_panel.open_profile_settings()
    profile.set_name(new_name)
    ChangesDetectedToastMessage().save_changes()
    _post(main_screen, community)


def _set_online(main_screen, online: bool):
    identifier = main_screen.left_panel.open_online_identifier()
    (identifier.always_active_button if online else identifier.inactive_button).click()


def _setup_community(main_screen, bob, aut_bob, members) -> RandomCommunity:
    """``members``: (aut, account) pairs; each becomes Bob's contact and gets an invite."""
    for aut, account in members:
        add_mutual_contact_via_activity_center(aut_bob, aut, main_screen, bob, account)
    switch_to_aut(aut_bob, main_screen)
    community = RandomCommunity()
    main_screen.left_panel.create_community(community_data=community)
    screen = _open_community(main_screen, community)
    screen.left_panel.open_add_members_popup().invite([a.name for _, a in members], message=random_text_message())
    main_screen.minimize()
    return community


def _join(aut, main_screen, bob, account, community):
    switch_to_aut(aut, main_screen)
    join_community_from_invite(main_screen, bob.name, account.password, community.name)


def _leave_community_view(main_screen) -> float:
    main_screen.left_panel.open_messages_screen()
    return time.monotonic()


def _finish_idle_release(left_at: float):
    remaining = IDLE_RELEASE_SEC - (time.monotonic() - left_at)
    if remaining > 0:
        time.sleep(remaining)


def _close_popup(main_screen):
    main_screen.left_panel.click()


@pytest.mark.roster_live
@pytest.mark.communities
@pytest.mark.timeout(timeout=2400)
def test_roster_stranger_placeholder_and_presence(multiple_instances):
    """PH-01..PH-06, ST-01, ST-02."""
    tester, bob, alice = _user('mm'), _user('bb'), _user('aa')
    frank = _user('ff', set_display_name=False)
    main_screen = MainWindow()

    with multiple_instances(user_data=None) as aut_tester, multiple_instances(user_data=None) as aut_bob, \
            multiple_instances(user_data=None) as aut_alice, multiple_instances(user_data=None) as aut_frank:
        with step('Launch Tester, Bob, Alice and Frank (no display name)'):
            for aut, account in ((aut_tester, tester), (aut_bob, bob), (aut_alice, alice), (aut_frank, frank)):
                authorize_user_in_aut(aut, main_screen, account)
            frank.name = get_user_display_name(aut_frank, main_screen)
            main_screen.minimize()

        community = _setup_community(main_screen, bob, aut_bob,
                                     [(aut_tester, tester), (aut_alice, alice), (aut_frank, frank)])
        members = {tester.name, bob.name, alice.name, frank.name}

        # Alice joins before Tester and never posts, so Tester's status-go has no record of her: her first
        # status update makes the client cache a placeholder (id + generated alias) for her key.
        with step('Alice and Frank join first; Alice never posts'):
            _join(aut_alice, main_screen, bob, alice, community)
            main_screen.minimize()
            _join(aut_frank, main_screen, bob, frank, community)
            main_screen.minimize()

        with step('Tester joins, then leaves the community view so its roster is released'):
            _join(aut_tester, main_screen, bob, tester, community)
            left_at = _leave_community_view(main_screen)
            main_screen.minimize()

        with step('Alice sends status updates that reach Tester'):
            switch_to_aut(aut_alice, main_screen)
            _set_online(main_screen, False)
            _set_online(main_screen, True)
            main_screen.minimize()

        with step('PH-01: Tester opens the members panel after Alice\'s status reached it'):
            switch_to_aut(aut_tester, main_screen)
            _finish_idle_release(left_at)
            _open_community(main_screen, community)
            rows = _wait_names(members)
            _assert_no_generated_alias([_shown(r) for r in rows], allowed=[frank.name])
            _assert_canonical(rows)

        with step('PH-05: Frank shows the alias, sorted by it'):
            assert _row(rows, frank.name)['uses_default_name'], f'Frank should use the default name: {rows}'

        with step('PH-02: @mention suggestions show Alice by display name, alphabetically'):
            mentions = _wait_mentions(MessagesScreen().group_chat.mention_suggestion_names, {alice.name})
            _assert_no_generated_alias(mentions, allowed=[frank.name])
            _assert_alphabetical(mentions, members)
            main_screen.minimize()

        with step('PH-03 / ST-01: Alice\'s presence changes move only between groups'):
            for online in (False, True, False, True, False, True):
                switch_to_aut(aut_alice, main_screen)
                _set_online(main_screen, online)
                main_screen.minimize()
                switch_to_aut(aut_tester, main_screen)
                rows = _wait_rows(lambda r: (_row(r, alice.name) or {}).get('online') is online,
                                  f'Alice should show online={online}')
                assert {_shown(r) for r in rows} == members, f'Names changed on a presence update: {rows}'
                _assert_canonical(rows)
                main_screen.minimize()

        with step('PH-04: Alice posts; the name stays and the order holds'):
            switch_to_aut(aut_alice, main_screen)
            _post(main_screen, community)
            main_screen.minimize()
            switch_to_aut(aut_tester, main_screen)
            _assert_canonical(_wait_names(members))

        with step('ST-02: Tester\'s own status follows in the own row'):
            for online in (False, True):
                _set_online(main_screen, online)
                _open_community(main_screen, community)
                _wait_rows(lambda r: (_row(r, tester.name) or {}).get('online') is online,
                           f'Own row should show online={online}')

        with step('PH-06: cold start shows every display name'):
            aut_tester.restart()
            main_screen.prepare()
            main_screen.authorize_user(tester)
            _open_community(main_screen, community)
            rows = _wait_names(members)
            _assert_no_generated_alias([_shown(r) for r in rows], allowed=[frank.name])


@pytest.mark.roster_live
@pytest.mark.communities
@pytest.mark.timeout(timeout=2400)
def test_roster_live_renames(multiple_instances):
    """NAME-01, NAME-03, NAME-04, NAME-06, NAME-07, OWN-01, OWN-03, LC-03, ADM-01."""
    tester, bob, alice = _user('mm'), _user('bb'), _user('aa')
    main_screen = MainWindow()

    with multiple_instances(user_data=None) as aut_tester, multiple_instances(user_data=None) as aut_bob, \
            multiple_instances(user_data=None) as aut_alice:
        with step('Launch Tester, Bob and Alice'):
            for aut, account in ((aut_tester, tester), (aut_bob, bob), (aut_alice, alice)):
                authorize_user_in_aut(aut, main_screen, account)

        community = _setup_community(main_screen, bob, aut_bob, [(aut_tester, tester), (aut_alice, alice)])
        _join(aut_tester, main_screen, bob, tester, community)
        # Known issue (also on master): a roster loaded while Tester's own join lands misses the self row.
        # Reload it fresh: leave the view and let the idle release drop it.
        left_at = _leave_community_view(main_screen)
        main_screen.minimize()
        _join(aut_alice, main_screen, bob, alice, community)
        main_screen.minimize()

        with step('Tester has the members panel open'):
            switch_to_aut(aut_tester, main_screen)
            _finish_idle_release(left_at)
            _open_community(main_screen, community)
            _wait_names({tester.name, bob.name, alice.name})
            main_screen.minimize()

        alice_name = f'zz{_suffix()}'
        with step('NAME-01: Alice (stranger) renames and posts; the open panel follows and re-sorts'):
            switch_to_aut(aut_alice, main_screen)
            _rename(main_screen, community, alice_name)
            main_screen.minimize()
            switch_to_aut(aut_tester, main_screen)
            _assert_canonical(_wait_names({tester.name, bob.name, alice_name}))

        with step('NAME-06: @mention suggestions show the new name'):
            _wait_mentions(lambda: MessagesScreen().group_chat.mention_suggestion_names('zz'), {alice_name})
            main_screen.minimize()

        with step('ADM-01: Bob keeps Settings > Members open'):
            switch_to_aut(aut_bob, main_screen)
            settings = _open_community(main_screen, community).left_panel.open_community_settings()
            settings.left_panel.open_members().open_all_members_tab()
            main_screen.minimize()

        with step('NAME-07: a case-only rename keeps the row in place'):
            switch_to_aut(aut_tester, main_screen)
            index_before = [_shown(r) for r in MembersListPanel().member_rows].index(alice_name)
            main_screen.minimize()
            alice_name = alice_name.upper()
            switch_to_aut(aut_alice, main_screen)
            _rename(main_screen, community, alice_name)
            main_screen.minimize()
            switch_to_aut(aut_tester, main_screen)
            rows = _wait_names({tester.name, bob.name, alice_name})
            assert [_shown(r) for r in rows].index(alice_name) == index_before, f'Row moved on a case-only rename: {rows}'
            main_screen.minimize()

        with step('ADM-01: the Members tab shows the rename live'):
            switch_to_aut(aut_bob, main_screen)
            assert driver.wait_until(lambda: alice_name in MembersView().members_names, LIVE_MSEC), \
                f'Members tab should show {alice_name}: {MembersView().members_names}'
            CommunitySettingsScreen().left_panel.back_to_community()
            main_screen.minimize()

        bob_name = f'yy{_suffix()}'
        with step('NAME-04: Bob (mutual contact) renames and posts'):
            switch_to_aut(aut_bob, main_screen)
            _rename(main_screen, community, bob_name)
            main_screen.minimize()
            switch_to_aut(aut_tester, main_screen)
            _assert_canonical(_wait_names({tester.name, bob_name, alice_name}))

        with step('NAME-03: a rename while the roster is released shows on reopen'):
            left_at = _leave_community_view(main_screen)
            main_screen.minimize()
            alice_name = f'xx{_suffix()}'
            switch_to_aut(aut_alice, main_screen)
            _rename(main_screen, community, alice_name)
            main_screen.minimize()
            switch_to_aut(aut_tester, main_screen)
            _finish_idle_release(left_at)
            _open_community(main_screen, community)
            _wait_names({tester.name, bob_name, alice_name})

        tester_name = f'tt{_suffix()}'
        with step('OWN-01: Tester renames; the own row follows'):
            _rename(main_screen, community, tester_name)
            _assert_canonical(_wait_names({tester_name, bob_name, alice_name}))
            main_screen.minimize()

        with step('OWN-03: Alice (stranger to Tester) and Bob see Tester\'s new name'):
            for aut in (aut_alice, aut_bob):
                switch_to_aut(aut, main_screen)
                _open_community(main_screen, community)
                _wait_names({tester_name, bob_name, alice_name})
                main_screen.minimize()

        with step('LC-03: after a restart Tester still shows the latest names'):
            switch_to_aut(aut_tester, main_screen)
            aut_tester.restart()
            main_screen.prepare()
            main_screen.authorize_user(UserAccount(name=tester_name, password=tester.password))
            _open_community(main_screen, community)
            rows = _wait_names({tester_name, bob_name, alice_name})
            _assert_no_generated_alias([_shown(r) for r in rows])


@pytest.mark.roster_live
@pytest.mark.communities
@pytest.mark.timeout(timeout=2400)
def test_roster_relations(multiple_instances):
    """REL-01..REL-07, LC-01, LC-04, INV-01."""
    tester, bob, carol, dave, erin = _user('mm'), _user('bb'), _user('cc'), _user('dd'), _user('ee')
    main_screen = MainWindow()

    with multiple_instances(user_data=None) as aut_tester, multiple_instances(user_data=None) as aut_bob, \
            multiple_instances(user_data=None) as aut_carol, multiple_instances(user_data=None) as aut_dave, \
            multiple_instances(user_data=None) as aut_erin:
        with step('Launch Tester, Bob, Carol, Dave and Erin'):
            for aut, account in ((aut_tester, tester), (aut_bob, bob), (aut_carol, carol), (aut_dave, dave),
                                 (aut_erin, erin)):
                authorize_user_in_aut(aut, main_screen, account)

        community = _setup_community(main_screen, bob, aut_bob, [(aut_tester, tester), (aut_carol, carol),
                                                                 (aut_dave, dave), (aut_erin, erin)])
        _join(aut_tester, main_screen, bob, tester, community)
        # Known issue (also on master): a roster loaded while Tester's own join lands misses the self row.
        # Reload it fresh: leave the view and let the idle release drop it.
        left_at = _leave_community_view(main_screen)
        main_screen.minimize()
        for aut, account in ((aut_carol, carol), (aut_dave, dave)):
            _join(aut, main_screen, bob, account, community)
            main_screen.minimize()
        names = {tester.name, bob.name, carol.name, dave.name}

        with step('Tester opens the members panel'):
            switch_to_aut(aut_tester, main_screen)
            _finish_idle_release(left_at)
            _open_community(main_screen, community)
            _wait_names(names)
            main_screen.minimize()

        with step('REL-01: Carol sends Tester a request, then renames'):
            tester_key = get_chat_key(aut_tester, main_screen)
            main_screen.minimize()
            send_contact_request_from_settings(aut_carol, main_screen, tester_key, f'Hello {tester.name}')
            names.discard(carol.name)
            carol.name = f'cc{_suffix()}'
            _rename(main_screen, community, carol.name)
            names.add(carol.name)
            main_screen.minimize()
            switch_to_aut(aut_tester, main_screen)
            _open_community(main_screen, community)
            _wait_names(names)
            main_screen.minimize()

        with step('REL-02: Tester sends Dave a request, then Dave renames'):
            dave_key = get_chat_key(aut_dave, main_screen)
            main_screen.minimize()
            send_contact_request_from_settings(aut_tester, main_screen, dave_key, f'Hello {dave.name}')
            main_screen.minimize()
            names.discard(dave.name)
            dave.name = f'dd{_suffix()}'
            switch_to_aut(aut_dave, main_screen)
            _rename(main_screen, community, dave.name)
            names.add(dave.name)
            main_screen.minimize()
            switch_to_aut(aut_tester, main_screen)
            _open_community(main_screen, community)
            _wait_names(names)

        with step('REL-04: blocking and unblocking Dave keeps the name'):
            panel = MembersListPanel()
            panel.click_member(dave.name).block_user().block_user_button.click()
            _wait_rows(lambda r: (_row(r, dave.name) or {}).get('is_blocked') is True, 'Dave should show blocked')
            panel.click_member(dave.name).unblock_user().unblock_user_button.click()
            _wait_rows(lambda r: (_row(r, dave.name) or {}).get('is_blocked') is False, 'Dave should show unblocked')
            _wait_names(names)
            main_screen.minimize()

        with step('LC-04: Erin joins while the panel is open'):
            _join(aut_erin, main_screen, bob, erin, community)
            main_screen.minimize()
            names.add(erin.name)
            switch_to_aut(aut_tester, main_screen)
            _assert_canonical(_wait_names(names))

        nickname = f'zed{_suffix()}'
        with step('REL-06: a nickname on Erin (never messaged Tester) keeps the display name too'):
            MembersListPanel().click_member(erin.name).set_nickname(nickname)
            _close_popup(main_screen)
            rows = _wait_rows(lambda r: (_row(r, nickname) or {}).get('name') == erin.name,
                              f'Erin should show nickname {nickname} over display name {erin.name}')
            _assert_canonical(rows)

        with step('REL-07: removing the nickname brings the display name back'):
            MembersListPanel().click_member(erin.name).remove_nickname()
            _close_popup(main_screen)
            _assert_canonical(_wait_names(names))
            main_screen.minimize()

        with step('REL-03: Erin becomes Tester\'s contact'):
            add_mutual_contact_via_activity_center(aut_tester, aut_erin, main_screen, tester, erin)
            switch_to_aut(aut_tester, main_screen)
            _open_community(main_screen, community)
            _wait_rows(lambda r: (_row(r, erin.name) or {}).get('is_contact') is True, 'Erin should show as contact')

        with step('REL-05: Tester removes Erin; Erin\'s rename still shows live'):
            MembersListPanel().click_member(erin.name).choose_context_menu_option('Remove contact')
            RemoveContactPopup().wait_until_appears().remove_contact_button.click()
            _close_popup(main_screen)
            main_screen.minimize()
            names.discard(erin.name)
            erin.name = f'ee{_suffix()}'
            switch_to_aut(aut_erin, main_screen)
            _rename(main_screen, community, erin.name)
            names.add(erin.name)
            main_screen.minimize()
            switch_to_aut(aut_tester, main_screen)
            _wait_names(names)
            main_screen.minimize()

        with step('INV-01: Bob\'s invite list leaves out members'):
            switch_to_aut(aut_bob, main_screen)
            popup = _open_community(main_screen, community).left_panel.open_add_members_popup()
            members = names - {bob.name}
            assert driver.wait_until(lambda: not members & set(popup.contacts), LIVE_MSEC), \
                f'Members should not be offered for invite: {popup.contacts}'
            popup.close()
            main_screen.minimize()

        with step('LC-04: Carol leaves while Tester\'s panel is open'):
            switch_to_aut(aut_carol, main_screen)
            main_screen.left_panel.open_community_context_menu(community.name).open_leave_community_popup().confirm_action()
            main_screen.minimize()
            names.discard(carol.name)
            switch_to_aut(aut_tester, main_screen)
            _wait_names(names)

        with step('LC-01: Tester leaves and rejoins; names are right after the reload'):
            main_screen.left_panel.open_community_context_menu(community.name).open_leave_community_popup().confirm_action()
            join_community_from_invite(main_screen, bob.name, tester.password, community.name)
            rows = _wait_names(names)
            _assert_no_generated_alias([_shown(r) for r in rows])


@pytest.mark.roster_live
@pytest.mark.communities
@pytest.mark.timeout(timeout=2400)
@pytest.mark.skipif(not THREADS_ENABLED, reason='threads need FLAG_THREADS_ENABLED=1')
def test_roster_thread_composer(multiple_instances):
    """THR-01..THR-04: the thread composer's @mentions come from the roster."""
    tester, bob, alice, erin = _user('mm'), _user('bb'), _user('aa'), _user('ee')
    main_screen = MainWindow()

    with multiple_instances(user_data=None) as aut_tester, multiple_instances(user_data=None) as aut_bob, \
            multiple_instances(user_data=None) as aut_alice, multiple_instances(user_data=None) as aut_erin:
        with step('Launch Tester, Bob, Alice and Erin'):
            for aut, account in ((aut_tester, tester), (aut_bob, bob), (aut_alice, alice), (aut_erin, erin)):
                authorize_user_in_aut(aut, main_screen, account)

        community = _setup_community(main_screen, bob, aut_bob,
                                     [(aut_tester, tester), (aut_alice, alice), (aut_erin, erin)])
        members = {tester.name, bob.name, alice.name, erin.name}

        with step('Tester joins and leaves the community view; Alice and Erin join, Alice only sends status'):
            _join(aut_tester, main_screen, bob, tester, community)
            left_at = _leave_community_view(main_screen)
            main_screen.minimize()
            _join(aut_alice, main_screen, bob, alice, community)
            _set_online(main_screen, False)
            _set_online(main_screen, True)
            main_screen.minimize()
            _join(aut_erin, main_screen, bob, erin, community)
            main_screen.minimize()

        nickname = f'zed{_suffix()}'
        parent_text = random_text_message()
        with step('Tester sets nickname on Erin and posts a parent message'):
            switch_to_aut(aut_tester, main_screen)
            _finish_idle_release(left_at)
            _open_community(main_screen, community)
            _wait_names(members)
            MembersListPanel().click_member(erin.name).set_nickname(nickname)
            _close_popup(main_screen)
            _post(main_screen, community, parent_text)

        with step('THR-01 / THR-04: thread composer @mentions show Alice and Erin\'s nickname'):
            parent = MessagesScreen().chat.find_message_by_text(parent_text, 0)
            composer = open_thread_from_message(parent)
            mentions = _wait_mentions(composer.mention_suggestion_names, {alice.name, nickname})
            _assert_no_generated_alias(mentions)
            _assert_alphabetical(mentions, members - {erin.name} | {nickname})
            assert erin.name not in mentions, f'Erin should show as nickname {nickname}: {mentions}'

        with step('THR-04: a thread mentioning Erin renders the nickname'):
            composer.send_mentioning('hello', nickname)
            assert driver.wait_until(lambda: any(nickname in p for p in ChatInfoThreads().open().previews),
                                     LIVE_MSEC), 'Thread preview should show the nickname mention'
            main_screen.minimize()

        alice_name = f'zz{_suffix()}'
        with step('Alice renames and posts'):
            switch_to_aut(aut_alice, main_screen)
            _rename(main_screen, community, alice_name)
            main_screen.minimize()

        with step('THR-02: thread composer shows the new name; the mention renders with it'):
            switch_to_aut(aut_tester, main_screen)
            _open_community(main_screen, community)
            second_parent = random_text_message()
            _post(main_screen, community, second_parent)
            composer = open_thread_from_message(MessagesScreen().chat.find_message_by_text(second_parent, 0))
            _wait_mentions(lambda: composer.mention_suggestion_names('zz'), {alice_name})
            composer.send_mentioning('ping', alice_name)
            assert driver.wait_until(lambda: any(alice_name in p for p in ChatInfoThreads().open().previews),
                                     LIVE_MSEC), 'Thread preview should show the new name'
            main_screen.minimize()

        with step('THR-03: Alice starts a thread; Tester sees the current name on the card'):
            # Sanity check only: thread cards read the message model, not the roster.
            switch_to_aut(aut_alice, main_screen)
            alice_parent = random_text_message()
            _post(main_screen, community, alice_parent)
            composer = open_thread_from_message(MessagesScreen().chat.find_message_by_text(alice_parent, 0))
            composer.send_mentioning('from alice', tester.name)
            alice_name = f'zy{_suffix()}'
            _rename(main_screen, community, alice_name)
            main_screen.minimize()
            switch_to_aut(aut_tester, main_screen)
            _open_community(main_screen, community)
            assert driver.wait_until(lambda: alice_name in ChatInfoThreads().open().senders, LIVE_MSEC), \
                f'Thread card sender should be {alice_name}: {ChatInfoThreads().senders}'
