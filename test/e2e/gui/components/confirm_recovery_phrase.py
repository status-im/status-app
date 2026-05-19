import allure

import configs
import driver
from gui.elements.button import Button
from gui.elements.object import QObject, set_text_property_on_object
from gui.keep_or_delete_recovery_phrase import KeepOrDeleteRecoveryPhrase
from gui.objects_map import names

_EXPECTED_SEED_VERIFY_FIELDS = 4


def _seed_cell_object_name(cell) -> str:
    name = getattr(cell, 'objectName', None)
    if name:
        return str(name)
    try:
        return str(cell['objectName'])
    except (TypeError, KeyError, AttributeError):
        return ''


def _seed_cell_object_name(cell) -> str:
    """Squish remote objects expose objectName as an attribute."""
    name = getattr(cell, 'objectName', None)
    if name:
        return str(name)
    try:
        return str(cell['objectName'])
    except (TypeError, KeyError, AttributeError):
        return ''


class ConfirmRecoveryPhrase(QObject):
    def __init__(self):
        super().__init__(names.confirmRecoveryPhraseModal)

        self.seed_input = QObject(names.seedInput)
        self.continue_button = Button(names.continueButton)

    def _wait_for_seed_verify_inputs(self, timeout_msec: int = None) -> list:
        if timeout_msec is None:
            timeout_msec = configs.timeouts.LOADING_LIST_TIMEOUT_MSEC

        def _ready() -> bool:
            raw = list(driver.findAllObjects(self.seed_input.real_name))
            filtered = [c for c in raw if _seed_cell_object_name(c).startswith('seedInput_')]
            return len(filtered) >= _EXPECTED_SEED_VERIFY_FIELDS

        assert driver.waitFor(_ready, timeout_msec), (
            f'Expected at least {_EXPECTED_SEED_VERIFY_FIELDS} SeedphraseVerifyInput fields '
            f'with objectName seedInput_*; UI may still be loading on slow runners.'
        )
        raw = list(driver.findAllObjects(self.seed_input.real_name))
        return [c for c in raw if _seed_cell_object_name(c).startswith('seedInput_')]

    @staticmethod
    def _mnemonic_index_from_cell_object_name(cell) -> int:
        name = _seed_cell_object_name(cell)
        suffix = name.rsplit('_', 1)[-1]
        try:
            return int(suffix)
        except ValueError as e:
            raise ValueError(f'Cannot parse mnemonic index from objectName={name!r} (cell={cell!r})') from e

    @allure.step('Fill in the grid and click continue')
    def fill_the_grid_and_continue(self, words):

        cells_to_fill = self._wait_for_seed_verify_inputs()
        assert len(cells_to_fill) >= _EXPECTED_SEED_VERIFY_FIELDS, (
            f'After filtering to seedInput_*, expected at least {_EXPECTED_SEED_VERIFY_FIELDS} cells, '
            f'got {len(cells_to_fill)}; raw findAllObjects may include unrelated overlay items.'
        )
        cells_to_fill.sort(key=lambda c: ConfirmRecoveryPhrase._mnemonic_index_from_cell_object_name(c))

        for cell in cells_to_fill:
            idx = self._mnemonic_index_from_cell_object_name(cell)
            word_to_put = words[idx]
            set_text_property_on_object(cell, word_to_put, configs.timeouts.UI_LOAD_TIMEOUT_MSEC)

        assert driver.waitFor(
            lambda: self.continue_button.is_enabled,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), (
            'Continue stayed disabled'
        )
        self.continue_button.click()
        return KeepOrDeleteRecoveryPhrase()
