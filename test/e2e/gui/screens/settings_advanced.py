import time

import allure

from gui.components.settings.confirm_switch_waku_mode_popup import SwitchWakuModePopup
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.scroll import Scroll
from gui.objects_map import settings_names


class AdvancedSettingsView(QObject):

    def __init__(self):
        super().__init__(settings_names.mainWindow_AdvancedView)
        self.scroll = Scroll(settings_names.settingsContentBase_ScrollView)
        self.manage_community_on_testnet_button = Button(
            settings_names.manageCommunitiesOnTestnetButton_StatusSettingsLineButton)
        self.minimize_to_tray_on_close_button = Button(settings_names.minimizeToTrayOnCloseButton)
        self.rpc_statistics_button = Button(settings_names.rpcStatisticsButton)
        self.light_mode_button = Button(settings_names.settingsContentBaseScrollViewLightWakuModeBloomSelectorButton)
        self.relay_mode_button = Button(settings_names.settingsContentBaseScrollViewRelayWakuModeBloomSelectorButton)

    @allure.step('Switch manage community on testnet option')
    def enable_manage_communities_on_testnet_toggle(self, attempts: int = 3, wait_timeout: float = 1.0):
        for _ in range(attempts):
            if not self.rpc_statistics_button.is_visible:
                self.scroll.vertical_scroll_down(self.rpc_statistics_button)

            if self.manage_community_on_testnet_button.object.checked:
                return self

            self.manage_community_on_testnet_button.click()
            for _ in range(5):
                if self.manage_community_on_testnet_button.object.checked:
                    return self
                time.sleep(wait_timeout / 5)
        raise RuntimeError('Could not enable Manage communities on testnet toggle')

    @allure.step('Set minimize to tray on close to {enabled}')
    def set_minimize_to_tray_on_close(self, enabled: bool):
        toggle = self.minimize_to_tray_on_close_button
        self.scroll.vertical_scroll_down(toggle)
        if toggle.is_checked != enabled:
            toggle.click()
        assert toggle.is_checked == enabled

    @allure.step('Switch waku mode')
    def switch_waku_mode(self, mode):
        if not self.manage_community_on_testnet_button.is_visible:
            self.scroll.vertical_scroll_down(self.manage_community_on_testnet_button)
        if mode == 'light':
            self.light_mode_button.click()
        elif mode == 'relay':
            self.relay_mode_button.click()
        return SwitchWakuModePopup().wait_until_appears()

    @allure.step('Verify waku mode enabled states')
    def is_waku_mode_enabled(self, mode):
        if not self.manage_community_on_testnet_button.is_visible:
            self.scroll.vertical_scroll_down(self.manage_community_on_testnet_button)
        if mode == 'light':
            return self.light_mode_button.is_checked
        elif mode == 'relay':
            return self.relay_mode_button.is_checked
