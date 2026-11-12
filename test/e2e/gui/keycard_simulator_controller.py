import socket

import allure

import configs
import driver
from gui.elements.button import Button
from gui.elements.check_box import CheckBox
from gui.elements.object import QObject
from gui.elements.window import Window
from gui.objects_map import keycard_names

_KEYCARD_SIMULATOR_HOST = '127.0.0.1'
_KEYCARD_SIMULATOR_PORT = 9025


class KeycardSimulatorController(Window):

    def __init__(self, app_window: Window | None = None):
        super().__init__(keycard_names.keycardSimulatorWindow)
        self._app_window = app_window
        self._start_button = Button(keycard_names.keycardSimStartButton)
        self._create_empty_button = Button(keycard_names.keycardSimCreateEmptyButton)
        self._plug_reader_button = Button(keycard_names.keycardSimPlugReaderButton)
        self._insert_button = Button(keycard_names.keycardSimInsertButton)
        self._remove_button = Button(keycard_names.keycardSimRemoveButton)
        self._card_id_field = QObject(keycard_names.keycardSimCardId)
        self._card_selector = QObject(keycard_names.keycardSimCardSelector)
        self._seed_field = QObject(keycard_names.keycardSimSeed)
        self._pin_field = QObject(keycard_names.keycardSimPin)
        self._puk_field = QObject(keycard_names.keycardSimPuk)
        self._create_with_seed_button = Button(keycard_names.keycardSimCreateWithSeedButton)
        self._use_tag_40 = CheckBox(keycard_names.keycardSimUseTag40)
        self._untrusted_ca = CheckBox(keycard_names.keycardSimUntrustedCa)
        self._counterfeit_button = Button(keycard_names.keycardSimCounterfeitButton)
        self.applet_40 = False

    def prepare(self) -> 'KeycardSimulatorController':
        return self

    def background(self) -> 'KeycardSimulatorController':
        if self._app_window is not None:
            self._app_window.set_focus()
        return self

    def rebind_app_window(self, app_window: Window) -> 'KeycardSimulatorController':
        self._app_window = app_window
        return self

    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        driver.waitFor(lambda: self._start_button.exists, timeout_msec)
        return self

    @property
    def is_reader_plugged(self) -> bool:
        try:
            plug_obj = driver.waitForObjectExists(self._plug_reader_button.real_name, 200)
            return not bool(getattr(plug_obj, 'enabled', True))
        except (LookupError, RuntimeError, AttributeError):
            return False

    @property
    def is_card_inserted(self) -> bool:
        try:
            obj = driver.waitForObjectExists(self._remove_button.real_name, 200)
            return bool(getattr(obj, 'enabled', False))
        except (LookupError, RuntimeError, AttributeError):
            return False

    def _set_checkbox(self, checkbox: CheckBox, value: bool):
        if checkbox.is_enabled:
            checkbox.set(value)
            return
        assert checkbox.is_checked == value, 'Keycard simulator checkbox is locked in the wrong state'

    @allure.step('Click Start Keycard Simulator')
    def start_simulator(self, applet_40: bool | None = None):
        if applet_40 is not None:
            self.applet_40 = applet_40
        self._set_checkbox(self._use_tag_40, self.applet_40)
        self._start_button.click()
        self._plug_reader_button.wait_until_enabled(configs.timeouts.KEYCARD_SIM_START_TIMEOUT_MSEC)
        driver.waitFor(
            lambda: not self._simulator_ping_ok(),
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        )
        assert driver.waitFor(
            self._simulator_ping_ok,
            configs.timeouts.KEYCARD_SIM_START_TIMEOUT_MSEC,
        ), 'Keycard simulator did not accept PING'
        return self.background()

    @allure.step('Create empty keycard {card_id}')
    def create_empty_card(self, card_id: str, untrusted_ca: bool = False):
        self._untrusted_ca.set(untrusted_ca)
        self._card_id_field.set_text_property(card_id)
        self._create_empty_button.wait_until_enabled()
        self._create_empty_button.click()
        status_name = keycard_names.keycardSimCreationStatus
        assert driver.waitFor(
            lambda: card_id in self._card_ids() or 'not created' in self._status_text(status_name),
            configs.timeouts.KEYCARD_SIM_START_TIMEOUT_MSEC,
        ), f'Keycard {card_id!r} was not created: {self._status_text(status_name)!r}'
        status = self._status_text(status_name)
        assert 'not created' not in status, status
        return self.select_card(card_id)

    @allure.step('Create keycard {card_id} from seed')
    def create_card_with_seed(
            self, card_id: str, seed_phrase: str, pin: str, puk: str, untrusted_ca: bool = False,
    ):
        self._untrusted_ca.set(untrusted_ca)
        self._card_id_field.set_text_property(card_id)
        self._seed_field.set_text_property(seed_phrase)
        self._pin_field.set_text_property(pin)
        self._puk_field.set_text_property(puk)
        self._create_with_seed_button.wait_until_enabled()
        self._create_with_seed_button.click()
        status_name = keycard_names.keycardSimCreationStatus
        expected_prefix = f'Keycard "{card_id}"'
        assert driver.waitFor(
            lambda: self._status_text(status_name).startswith(expected_prefix),
            configs.timeouts.KEYCARD_SIM_START_TIMEOUT_MSEC,
        ), f'Timed out loading Keycard {card_id!r}'
        status = self._status_text(status_name)
        assert status == f'{expected_prefix} created', status
        return self.select_card(card_id)

    @allure.step('Make selected keycard counterfeit')
    def make_counterfeit(self, card_id: str):
        self.select_card(card_id)
        self._click_sim_button(self._counterfeit_button)
        status = self._status_text(keycard_names.keycardSimCounterfeitStatus)
        assert status == f'Keycard "{card_id}" is now counterfeit', status
        return self.background()

    def _status_text(self, real_name: dict) -> str:
        obj = driver.waitForObjectExists(real_name, 200)
        return str(obj.text)

    def _click_sim_button(self, button: Button):
        button.wait_until_enabled()
        button.object.click()
        return self

    @allure.step('Wait until keycard reader is plugged in simulator')
    def wait_until_reader_plugged(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        assert driver.waitFor(lambda: self.is_reader_plugged, timeout_msec), (
            'Keycard reader was not plugged in simulator'
        )
        return self

    @allure.step('Wait until keycard is inserted in simulator')
    def wait_until_card_inserted(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        assert driver.waitFor(lambda: self.is_card_inserted, timeout_msec), (
            'Keycard was not inserted in simulator'
        )
        return self

    @allure.step('Plug keycard reader')
    def plug_reader(self):
        if self.is_reader_plugged:
            return self.background()
        self._click_sim_button(self._plug_reader_button)
        self.wait_until_reader_plugged()
        return self.background()

    @allure.step('Insert selected keycard')
    def insert_card(self):
        if self.is_card_inserted:
            return self.background()
        self._click_sim_button(self._insert_button)
        self.wait_until_card_inserted()
        return self.background()

    @allure.step('Select keycard {card_id} in simulator')
    def select_card(self, card_id: str):
        assert driver.waitFor(
            lambda: card_id in self._card_ids(),
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), f'Keycard {card_id!r} not found in simulator selector'

        combo = self._card_selector_combo()
        for index, item_id in enumerate(self._card_ids()):
            if item_id == card_id:
                combo.currentIndex = index
                break
        else:
            raise LookupError(f'Keycard {card_id!r} not found in simulator selector')

        assert driver.waitFor(
            lambda: combo.currentIndex >= 0 and self._selected_card_id() == card_id,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), f'Failed to select keycard {card_id!r} in simulator'
        return self.background()

    def _card_selector_combo(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        return driver.waitForObjectExists(self._card_selector.real_name, timeout_msec)

    def _card_ids(self) -> list[str]:
        try:
            combo = self._card_selector_combo(200)
        except (LookupError, RuntimeError):
            return []
        return [str(combo.textAt(index)) for index in range(combo.count)]

    def _selected_card_id(self) -> str:
        try:
            combo = self._card_selector_combo(200)
        except (LookupError, RuntimeError):
            return ''
        if combo.currentIndex < 0:
            return ''
        return str(combo.textAt(combo.currentIndex))

    def _simulator_ping_ok(self) -> bool:
        try:
            with socket.create_connection(
                (_KEYCARD_SIMULATOR_HOST, _KEYCARD_SIMULATOR_PORT), timeout=1
            ) as sock:
                sock.sendall(b'PING\n')
                sock.settimeout(1)
                data = sock.recv(64)
            return data.decode('utf-8', errors='replace').strip().startswith('OK')
        except OSError:
            return False
