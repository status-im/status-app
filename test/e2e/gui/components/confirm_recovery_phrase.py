import allure

import driver
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.keep_or_delete_recovery_phrase import KeepOrDeleteRecoveryPhrase
from gui.objects_map import names


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

    @allure.step('Fill in the grid and click continue')
    def fill_the_grid_and_continue(self, words):

        cells_to_fill = driver.findAllObjects(self.seed_input.real_name)

        def _cell_sort_key(cell):
            oname = _seed_cell_object_name(cell)
            try:
                return int(oname.split('_')[1])
            except (IndexError, ValueError):
                return 0

        for cell in sorted(cells_to_fill, key=_cell_sort_key):
            oname = _seed_cell_object_name(cell)
            word_to_confirm_index = int(oname.split('_')[1])
            word_to_put = words[word_to_confirm_index]
            self.seed_input.real_name['objectName'] = f'seedInput_{word_to_confirm_index}'
            self.seed_input.set_text_property(word_to_put)

        # Footer Continue stays disabled until seedRepeater.allValid; wait for enabled, not inline btnContinue visibility.
        self.continue_button.wait_until_enabled()
        self.continue_button.click()
        return KeepOrDeleteRecoveryPhrase()
