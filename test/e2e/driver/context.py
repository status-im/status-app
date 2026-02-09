import logging
import time

import allure
import squish

import configs
import driver
from driver.server import SquishServer
from configs.system import get_platform

LOG = logging.getLogger(__name__)


@allure.step('Get application context of "{0}"')
def get_context(aut_id: str):
    """
    Get application context with retry logic for slow first startup on Windows VMs.
    On Windows, the first app start after install can be slow, so we retry a few times.
    """
    is_windows = get_platform() == "Windows"
    max_retries = 3 if is_windows else 1
    retry_delay = 1.0 if is_windows else 0.0
    
    LOG.info('Attaching to: %s', aut_id)
    
    last_error = None
    for attempt in range(max_retries):
        try:
            context = driver.attachToApplication(aut_id, SquishServer().host, SquishServer().port)
            if context is not None:
                if attempt > 0:
                    LOG.info('AUT %s context found on attempt %d', aut_id, attempt + 1)
                return context
        except RuntimeError as error:
            last_error = error
            if attempt < max_retries - 1:
                LOG.warning('AUT %s not ready (attempt %d/%d), retrying in %.1fs...', 
                           aut_id, attempt + 1, max_retries, retry_delay)
                time.sleep(retry_delay)
            else:
                LOG.error('AUT %s context not found after %d attempts', aut_id, max_retries)
    
    raise last_error


@allure.step('Detaching')
def detach():
    for ctx in driver.applicationContextList():
        ctx.detach()
        assert squish.waitFor(lambda: not ctx.isRunning, configs.timeouts.APP_LOAD_TIMEOUT_MSEC)
    LOG.info('All AUTs detached')
