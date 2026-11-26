ensure_dotenv() {
    if [ ! -f .env ]; then
        cp .env.example .env
        echo "setup: created .env from .env.example" >&2
    fi
    for key in E2E_LOCAL_WAKU_FLEET WALLET_TEST_USER_SEED; do
        if ! grep -qE "^${key}=" .env 2>/dev/null; then
            line=$(grep -E "^${key}=" .env.example 2>/dev/null | head -1)
            if [ -n "$line" ]; then
                printf '\n%s\n' "$line" >> .env
                echo "setup: added ${key} to .env" >&2
            else
                echo "setup: add ${key}= to .env" >&2
            fi
        fi
    done
    if ! grep -qE '^WALLET_TEST_USER_SEED=.+$' .env 2>/dev/null; then
        echo "setup: set WALLET_TEST_USER_SEED in .env (Jenkins credential wallet-test-user-seed)" >&2
    fi
}