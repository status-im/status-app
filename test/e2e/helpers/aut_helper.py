import allure

import configs
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
