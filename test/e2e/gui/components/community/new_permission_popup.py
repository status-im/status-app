import allure
from gui.elements.button import Button
from gui.elements.check_box import CheckBox
from gui.elements.object import QObject
from gui.elements.text_edit import TextEdit
from gui.objects_map import communities_names
from gui.screens.community_settings import PermissionsSettingsView


class NewPermissionPopup(PermissionsSettingsView):
    def __init__(self):
        super(NewPermissionPopup, self).__init__()
        self._who_holds_checkbox = CheckBox(communities_names.whoHoldsSwitch_StatusSwitch)
        self._who_holds_asset_field = TextEdit(communities_names.holdingsDropdown_assetSearch_TextEdit)
        self._who_holds_amount_field = TextEdit(communities_names.inputValue_StyledTextField)
        self._asset_item = QObject(communities_names.o_TokenItem)
        self._is_allowed_to_option_button = Button(communities_names.customPermissionListItem)
        self._hide_permission_checkbox = CheckBox(communities_names.switchItem_StatusSwitch)
        self._create_permission_button = Button(communities_names.create_permission_StatusButton)
        self._add_button_who_holds = Button(communities_names.add_update_statusButton)
        self._add_button_is_allowed_to = Button(communities_names.add_StatusButton)
        self._who_holds_list_item = QObject(communities_names.who_holds_StatusItemSelector)
        self._is_allowed_to_list_item = QObject(communities_names.is_allowed_to_StatusFlowSelector)

    @allure.step('Click create permission')
    def create_permission(self):
        self._create_permission_button.click()
        self._create_permission_button.wait_until_hidden()
