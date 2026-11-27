import os
import platform


def get_platform():
    return platform.system()


DISPLAY = os.getenv('DISPLAY', ':0')
# Below OS ephemeral ranges (Linux from 32768, macOS/Windows from 49152).
AUT_PORT = 25000 + int(os.getenv('EXECUTOR_NUMBER', 0))
TEST_MODE = os.getenv('STATUS_RUNTIME_TEST_MODE')

