import os

# Below the OS ephemeral range so the second AUT hook is not stolen by the first instance.
AUT_PORT = 35100 + int(os.getenv('EXECUTOR_NUMBER', 0))
SERVER_PORT = 4322 + int(os.getenv('EXECUTOR_NUMBER', 0))
CURSOR_ANIMATION = False
