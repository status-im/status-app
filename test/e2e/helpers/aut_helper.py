import allure

import configs
import driver
from configs.system import get_platform
from configs.timeouts import APP_LOAD_TIMEOUT_MSEC
from driver.aut import AUT
from gui.main_window import MainWindow


@allure.step('Launch AUT with a fresh data directory (new device)')
def launch_fresh_aut(keycard_simulator=None):
    fresh_aut = AUT()
    fresh_aut.launch()
    main_window = MainWindow().wait_until_appears().prepare()
    if keycard_simulator is not None:
        keycard_simulator.rebind_app_window(main_window)
        keycard_simulator.wait_until_appears(
            configs.timeouts.APP_LOAD_TIMEOUT_MSEC
        ).start_simulator()
    return fresh_aut, main_window


@allure.step('Quit the application with StandardKey.Quit')
def quit_app(main_window, aut):
    assert aut.session is not None and aut.session.is_running, 'AUT is not running before the quit shortcut'
    main_window.set_focus()
    sequence = '<Command+q>' if get_platform() == 'Darwin' else '<Ctrl+q>'
    try:
        driver.type_text(main_window.object, sequence)
    except RuntimeError:
        if aut.session is not None and aut.session.is_running:
            raise
    assert aut.session is not None
    assert driver.wait_until(lambda: not aut.session.is_running, APP_LOAD_TIMEOUT_MSEC), \
        'Application did not quit after the quit shortcut'
