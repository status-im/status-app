import os
import logging

LOG_LEVEL = logging.getLevelName(os.getenv('LOG_LEVEL', 'INFO'))
UPDATE_VP_ON_FAIL = False
DEV_BUILD = False
AUT_PATH = os.getenv('AUT_PATH')
