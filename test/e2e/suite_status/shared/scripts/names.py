# encoding: UTF-8
"""Squish IDE object map entrypoint.

Imports gui/objects_map modules by name so duplicate locator identifiers stay
namespaced the same way pytest uses them. New names picked in the IDE may be
appended here — copy them into the matching gui/objects_map/*.py file; this
file is not the source of truth.
"""
import sys
from pathlib import Path

from objectmaphelper import *

_E2E_ROOT = Path(__file__).resolve().parents[3]
if str(_E2E_ROOT) not in sys.path:
    sys.path.insert(0, str(_E2E_ROOT))

from gui.objects_map import names
from gui.objects_map import activity_center_names
from gui.objects_map import communities_names
from gui.objects_map import dapps_names
from gui.objects_map import home_names
from gui.objects_map import keycard_names
from gui.objects_map import messaging_names
from gui.objects_map import onboarding_names
from gui.objects_map import settings_names
from gui.objects_map import wallet_names
