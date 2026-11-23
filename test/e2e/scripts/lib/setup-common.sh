arm_host() {
    if command -v sysctl >/dev/null 2>&1; then
        [ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" = 1 ]
    else
        return 1
    fi
}

is_squish() {
    case "$1" in *[Ss]quish*) return 0 ;; esac
    case "$("$1" -c 'import sys; print(sys.base_prefix)' 2>/dev/null || true)" in
        *[Ss]quish*) return 0 ;;
    esac
    return 1
}

usable_314() {
    local py=$1 arch
    [ -n "$py" ] && [ -x "$py" ] || return 1
    is_squish "$py" && return 1
    [ "$("$py" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null || true)" = 3.14 ] || return 1
    if arm_host; then
        arch=$("$py" -c 'import platform; print(platform.machine())' 2>/dev/null || true)
        [ "$arch" = arm64 ] || return 1
    fi
    return 0
}

ensure_uv() {
    export PATH="$HOME/.local/bin:$PATH"
    if command -v uv >/dev/null 2>&1; then
        return
    fi
    command -v curl >/dev/null 2>&1 || {
        echo "setup: install curl" >&2
        exit 1
    }
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    command -v uv >/dev/null 2>&1 || {
        echo "setup: uv was not installed" >&2
        exit 1
    }
}

ensure_python() {
    local candidate py="" path_save=$PATH
    PATH=$(printf '%s\n' "$PATH" | tr ':' '\n' | grep -vi squish | grep -v "^${SETUP_ROOT}/.venv/bin$" | paste -sd: - || true)
    for candidate in \
        "$(command -v python3.14 2>/dev/null || true)" \
        /opt/homebrew/bin/python3.14 \
        /usr/local/bin/python3.14
    do
        if usable_314 "$candidate"; then
            py=$candidate
            break
        fi
    done
    PATH=$path_save
    if [ -z "$py" ]; then
        ensure_uv
        uv python install 3.14
        py=$(uv python find 3.14)
    fi
    if ! usable_314 "$py"; then
        echo "setup: Python 3.14 is not usable: $py" >&2
        exit 1
    fi
    printf '%s\n' "$py"
}

create_venv() {
    local py=$1 plugins=$2
    ensure_uv
    rm -rf .venv
    uv venv --python "$py" .venv
    uv pip install --python .venv/bin/python -r requirements.txt
    .venv/bin/python "$SETUP_ROOT/scripts/lib/record_plugins.py" "$plugins"
}
