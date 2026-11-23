start_waku_fleet() {
    local py=${1:?python for scan_waku_fleet.py}

    if [ "${E2E_SKIP_WAKU_FLEET:-}" = 1 ]; then
        echo "setup: E2E_SKIP_WAKU_FLEET=1, skipping local Waku fleet" >&2
        return 0
    fi

    local repo
    repo=$(CDPATH= cd -- "$SETUP_ROOT/../.." && pwd)
    local project=${E2E_WAKU_COMPOSE_PROJECT:-status-app}
    local compose="$repo/docker-compose.waku.yml"

    command -v docker >/dev/null 2>&1 || {
        echo "setup: docker not found, skipping Waku fleet" >&2
        return 0
    }
    docker info >/dev/null 2>&1 || {
        echo "setup: docker is not running, skipping Waku fleet" >&2
        return 0
    }
    [ -f "$compose" ] || {
        echo "setup: $compose not found" >&2
        return 1
    }

    echo "setup: starting Waku fleet (project=$project)" >&2
    docker compose -p "$project" -f "$compose" up -d --build --remove-orphans
    (cd "$repo" && "$py" test/e2e/scripts/scan_waku_fleet.py --project "$project")
    echo "setup: Waku fleet config at $repo/assets/local-waku-fleets-config.json" >&2
}