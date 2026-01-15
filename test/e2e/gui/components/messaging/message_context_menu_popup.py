import re

import allure

import configs
import driver
from driver.objects_access import walk_children
from gui.elements.object import QObject
from gui.objects_map import messaging_names


class MessageContextMenuPopup(QObject):

    def __init__(self):
        super().__init__(messaging_names.messageContextView)
        self._emoji_reaction = QObject(messaging_names.o_EmojiReaction)

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._emoji_reaction.wait_until_appears(timeout_msec)
        return self

    @allure.step('Get emoji code by occurrence')
    def get_emoji_code_by_occurrence(self, occurrence: int) -> str:
        """Get the actual emoji code from UI by occurrence (1-based)"""
        # Set occurrence in real_name to find the correct emoji element
        temp_real_name = self._emoji_reaction.real_name.copy()
        if occurrence > 1:
            temp_real_name['occurrence'] = occurrence
        else:
            # Remove occurrence for first element
            temp_real_name.pop('occurrence', None)
        
        # Find the emoji element
        emoji_obj = driver.waitForObject(temp_real_name, configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
        
        # Search for icon path inside the emoji element
        for item in walk_children(emoji_obj):
            icon_path = None
            if hasattr(item, 'icon'):
                icon_path = str(item.icon)
            elif hasattr(item, 'source'):
                icon_path = str(item.source)
            
            if icon_path:
                # Extract emoji ID from path like "qrc:/assets/twemoji/svg/1f600.svg"
                match = re.search(r'/([a-f0-9]+)\.svg', icon_path)
                if match:
                    return match.group(1)
        
        raise LookupError(f'Could not find emoji code for occurrence {occurrence}')

    @allure.step('Add reaction to message')
    def add_reaction_to_message(self, occurrence: int):
        # for 1st element occurrence is absent in real name, for other elements it starts from 2
        if occurrence > 1:
            self._emoji_reaction.real_name['occurrence'] = occurrence
        self._emoji_reaction.click()
