import pytest

from constants import KEYCARD_APPLET_3_2, KEYCARD_APPLET_4_0_1
from gui.keycard_simulator_controller import KeycardSimulatorController


@pytest.fixture
def keycard_simulator(request, main_window):
    version = getattr(request, 'param', KEYCARD_APPLET_3_2)
    sim = KeycardSimulatorController(app_window=main_window)
    return sim.wait_until_appears().start_simulator(applet_40=version == KEYCARD_APPLET_4_0_1)
