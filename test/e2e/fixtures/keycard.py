import pytest

from gui.keycard_simulator_controller import KeycardSimulatorController


@pytest.fixture
def keycard_simulator(main_window):
    sim = KeycardSimulatorController(app_window=main_window)
    return sim.wait_until_appears().start_simulator()
