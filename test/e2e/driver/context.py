import logging
import time

import allure
import squish

import configs
import driver
from driver.server import SquishServer

LOG = logging.getLogger(__name__)

_ALREADY_ATTACHED = 'another test is currently attached'
_ATTACH_RETRIES = 3
_ATTACH_RETRY_DELAY_SEC = 1.0


def _existing_context(aut_id: str):
    for ctx in driver.applicationContextList():
        name = getattr(ctx, 'name', None)
        if name == aut_id or str(ctx) == aut_id:
            return ctx
    return None


@allure.step('Get application context of "{0}"')
def get_context(aut_id: str):
    """
    Get application context with retry logic for slow AUT hook handshake.
    Do not retry 'already attached': the AUT is bound to this test; reuse the context.
    """
    LOG.info('Attaching to: %s', aut_id)

    existing = _existing_context(aut_id)
    if existing is not None:
        LOG.info('AUT %s already has an application context, reusing it', aut_id)
        return existing

    last_error = None
    for attempt in range(_ATTACH_RETRIES):
        try:
            context = driver.attachToApplication(aut_id, SquishServer().host, SquishServer().port)
            if context is not None:
                if attempt > 0:
                    LOG.info('AUT %s context found on attempt %d', aut_id, attempt + 1)
                return context
        except RuntimeError as error:
            last_error = error
            existing = _existing_context(aut_id)
            if existing is not None:
                LOG.info('AUT %s attached despite error (%s); reusing context', aut_id, error)
                return existing
            if _ALREADY_ATTACHED in str(error).lower():
                LOG.error('AUT %s is attached to another test: %s', aut_id, error)
                raise
            if attempt < _ATTACH_RETRIES - 1:
                LOG.warning('AUT %s not ready (attempt %d/%d), retrying in %.1fs...',
                           aut_id, attempt + 1, _ATTACH_RETRIES, _ATTACH_RETRY_DELAY_SEC)
                time.sleep(_ATTACH_RETRY_DELAY_SEC)
            else:
                LOG.error('AUT %s context not found after %d attempts', aut_id, _ATTACH_RETRIES)

    raise last_error


@allure.step('Detaching')
def detach():
    for ctx in driver.applicationContextList():
        ctx.detach()
        assert squish.waitFor(lambda: not ctx.isRunning, configs.timeouts.APP_LOAD_TIMEOUT_MSEC)
    LOG.info('All AUTs detached')
