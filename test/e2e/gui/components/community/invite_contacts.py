import typing

import allure
import pyperclip

import configs.timeouts
import driver
from gui.elements.button import Button
from gui.elements.check_box import CheckBox
from gui.elements.object import QObject
from gui.elements.text_edit import TextEdit
from gui.objects_map import names


class InviteContactsPopup(QObject):

    def __init__(self):
        super().__init__(names.inviteFriendsToCommunityPopup)
        self.invite_friends_to_community_popup = QObject(names.inviteFriendsToCommunityPopup)
        self.member_item = QObject(names.o_StatusMemberListItem)
        self.member_checkbox = CheckBox(names.memberListCheckbox)
        self.next_button = Button(names.next_StatusButton)
        self.message_text_edit = TextEdit(names.communityProfilePopupInviteMessagePanel_MessageInput_TextEdit)
        self.invited_member_item = QObject(names.o_StatusMemberListItem_2)
        self.send_button = Button(names.send_1_invite_StatusButton)
        self.copy_button = Button(names.copy_icon_StatusIcon)
        self.close_button = Button(names.closeButton)

    @property
    @allure.step('Get contacts')
    def contacts(self) -> typing.List[str]:
        return [str(user.userName) for user in driver.findAllObjects(self.member_item.real_name)]

    @property
    @allure.step('Invite contacts')
    def invited_contacts(self) -> typing.List[str]:
        return [str(user.userName) for user in driver.findAllObjects(self.invited_member_item.real_name)]

    def invite(self, contacts: typing.List[str], message: str):
        for contact in contacts:
            assert driver.waitFor(lambda: contact in self.contacts, configs.timeouts.UI_LOAD_TIMEOUT_MSEC), \
                f'Contact: {contact} not found in {self.contacts}'

        selected = []
        for member in driver.findAllObjects(self.member_checkbox.real_name):
            if str(getattr(member, 'objectName', '')).split('contactCheckbox-')[1] in contacts:
                CheckBox(member).set(True)
                assert member.checkState != 0, f"Member item checkbox is not checked"
                selected.append(str(getattr(member, 'objectName', '')).split('contactCheckbox-')[1])

        assert set(contacts) == set(selected), f'Selected contacts: {selected}, expected: {contacts}'

        self.next_button.click()
        self.message_text_edit.set_text_property(message)

        for contact in contacts:
            assert driver.waitFor(lambda: contact in self.invited_contacts, configs.timeouts.UI_LOAD_TIMEOUT_MSEC), \
                f'Contact: {contact} not found in {self.invited_contacts}'

        self.send_button.click()

    @allure.step('Copy community link')
    def copy_community_link(self):
        self.copy_button.click()
        return str(pyperclip.paste())
