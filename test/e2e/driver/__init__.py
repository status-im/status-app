import squishtest  # noqa

from . import server, context, objects_access, toplevel_window, mouse
from .squish_api import *

imports = {module.__name__: module for module in [
    context,
    objects_access,
    mouse,
    server,
    toplevel_window,
]}


def __getattr__(name):
    if name == 'aut':
        from . import aut as aut_module
        imports['aut'] = aut_module
        return aut_module
    if name in imports:
        return imports[name]
    try:
        return getattr(squishtest, name)
    except AttributeError:
        raise ImportError(f'Module "driver" has no attribute "{name}"')


squishtest.testSettings.waitForObjectTimeout = configs.timeouts.UI_LOAD_TIMEOUT_MSEC
squishtest.setHookSubprocesses(True)
