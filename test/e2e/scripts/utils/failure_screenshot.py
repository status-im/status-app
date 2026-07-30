import driver
import logging
from typing import Optional, Tuple

import allure
import cv2
import numpy as np
from PIL import ImageGrab

import configs
from configs.system import get_platform
from gui.objects_map.names import statusDesktop_mainWindow
from scripts.utils.system_path import SystemPath

LOG = logging.getLogger(__name__)

_SCREENSHOT_FAILURE_NOTE = (
    'Screenshot could not be captured. Common on Windows CI agents without an '
    'active interactive desktop session (RDP disconnected, screen locked).'
)


def _xdisplay():
    return configs.system.DISPLAY if get_platform() == "Linux" else None


def save_failure_screenshot(screenshot: SystemPath) -> Tuple[bool, Optional[str]]:
    """Capture AUT window via Squish bounds, then fall back to full-screen grab.

    Returns (success, failure_reason). failure_reason is set when both methods fail.
    """
    screenshot.parent.mkdir(parents=True, exist_ok=True)
    errors = []

    try:
        driver.waitForObjectExists(statusDesktop_mainWindow).setVisible(True)
        rect = driver.object.globalBounds(driver.waitForObject(statusDesktop_mainWindow))
        img = ImageGrab.grab(
            bbox=(rect.x, rect.y, rect.x + rect.width, rect.y + rect.height),
            xdisplay=_xdisplay(),
        )
        cv2.imwrite(str(screenshot), cv2.cvtColor(np.array(img), cv2.COLOR_BGR2RGB))
        return True, None
    except Exception as err:
        message = f'AUT window screenshot failed: {err}'
        LOG.debug(message)
        errors.append(message)

    try:
        ImageGrab.grab(xdisplay=_xdisplay()).save(screenshot)
        return True, None
    except (OSError, FileNotFoundError) as err:
        message = f'Full-screen screenshot failed: {err}'
        LOG.warning(message)
        errors.append(message)
    except Exception as err:
        message = f'Screenshot capture failed: {err}'
        LOG.warning(message)
        errors.append(message)

    return False, '\n'.join(errors)


def attach_failure_screenshot(screenshot: SystemPath, attachment_name: str = 'Screenshot on fail') -> bool:
    """Save a failure screenshot and attach it to Allure, or attach a text note on failure."""
    saved, failure_reason = save_failure_screenshot(screenshot)
    if saved:
        allure.attach(
            name=attachment_name,
            body=screenshot.read_bytes(),
            attachment_type=allure.attachment_type.PNG,
        )
        return True

    note = _SCREENSHOT_FAILURE_NOTE
    if failure_reason:
        note = f'{note}\n\nDetails:\n{failure_reason}'
    allure.attach(
        name='Screenshot on fail (unavailable)',
        body=note,
        attachment_type=allure.attachment_type.TEXT,
    )
    return False
