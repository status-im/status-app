import os

# Below OS ephemeral ranges (Linux from 32768, macOS/Windows from 49152).
AUT_PORT = 25000 + int(os.getenv('EXECUTOR_NUMBER', 0))
SERVER_PORT = 4322 + int(os.getenv('EXECUTOR_NUMBER', 0))
CURSOR_ANIMATION = False
