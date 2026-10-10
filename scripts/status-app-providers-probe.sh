#!/usr/bin/env bash
# status-app-providers-probe.sh
#
# Probes every external provider the Status desktop app depends on at runtime.
# Endpoint list extracted from status-go @ 10b7614c4 + status-desktop sources.
#
# Works WITHOUT any credentials: for authenticated proxies a 401/403 response
# proves the service is alive and its auth layer works (a block/outage shows up
# as timeout, connection reset, DNS failure, or 5xx instead).
#
# Usage:
#   status-app-providers-probe.sh          # human-readable output
#   status-app-providers-probe.sh --json   # machine-readable JSON on stdout
#
# Optional env vars for authenticated functional checks:
#   ETH_RPC_PROXY_USER / ETH_RPC_PROXY_PASSWORD
#   MARKET_PROXY_USER  / MARKET_PROXY_PASSWORD
#   NFT_PROXY_USER     / NFT_PROXY_PASSWORD
#   KLIPY_API_KEY
#   STAGE  (default: prod; the app uses test.* in dev builds, prod.* in release)
#
# Deps: curl, dig, nc. Exit code = number of failed (non-optional) checks.

set -u
STAGE="${STAGE:-prod}"
JSON=0
[[ "${1:-}" == "--json" ]] && JSON=1
FAIL=0
WARN=0
RPC_ALIVE=0          # counts alive RPC providers (proxy + fallbacks)
TOKENLIST_PRIMARY=0  # market proxy token lists reachable
CT=5   # connect timeout
MT=12  # max time
SECTION=""
RESULTS=""

section() {
  SECTION="$1"
  if [[ "$JSON" == 0 ]]; then [[ -n "$RESULTS" ]] && echo; echo "=== $1 ==="; fi
}

json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

record() { # status name detail
  local entry
  entry=$(printf '{"section":"%s","name":"%s","status":"%s","detail":"%s"}' \
    "$(json_escape "$SECTION")" "$(json_escape "$2")" "$1" "$(json_escape "$3")")
  RESULTS="${RESULTS:+$RESULTS,}$entry"
}

# GROUP=<var> before a check increments <var> on success (for "at least one
# alive" section verdicts). OPT=1 marks a check as a non-mandatory fallback:
# its failure prints WARN and does not count toward the exit code.
pass() {
  [[ "$JSON" == 0 ]] && printf '  \033[32mOK\033[0m   %-42s %s\n' "$1" "$2"
  record ok "$1" "$2"
  if [[ -n "${GROUP:-}" ]]; then eval "$GROUP=\$(( \$$GROUP + 1 ))"; fi
}
fail() {
  if [[ "${OPT:-0}" == "1" ]]; then
    [[ "$JSON" == 0 ]] && printf '  \033[33mWARN\033[0m %-42s %s — fallback, not mandatory\n' "$1" "$2"
    record warn "$1" "$2"
    WARN=$((WARN+1))
  else
    [[ "$JSON" == 0 ]] && printf '  \033[31mFAIL\033[0m %-42s %s\n' "$1" "$2"
    record fail "$1" "$2"
    FAIL=$((FAIL+1))
  fi
}

# http NAME URL EXPECTED_CODES [curl args...]
http() {
  local name="$1" url="$2" expect="$3"; shift 3
  local out code t
  out=$(curl -s -o /dev/null -w '%{http_code} %{time_total}' \
        --connect-timeout "$CT" -m "$MT" "$@" "$url" 2>/dev/null)
  code="${out%% *}"; t="${out##* }"
  if [[ ",$expect," == *",$code,"* ]]; then
    pass "$name" "HTTP $code ${t}s"
  else
    fail "$name" "HTTP ${code:-000} (expected $expect) ${t:-?}s"
  fi
}

rpc() { # JSON-RPC eth_blockNumber POST
  local name="$1" url="$2" expect="$3"; shift 3
  http "$name" "$url" "$expect" -X POST -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' "$@"
}

tcp() {
  local name="$1" host="$2" port="$3"
  if nc -z -w 5 "$host" "$port" >/dev/null 2>&1; then
    pass "$name" "TCP $port open"
  else
    fail "$name" "TCP $port unreachable"
  fi
}

dns_a() {
  local name="$1" host="$2"
  local a
  a=$(dig +short +time=5 A "$host" 2>/dev/null | head -1)
  if [[ -n "$a" ]]; then
    pass "$name" "resolves to $a"
  else
    fail "$name" "no DNS A record"
  fi
}

dns_txt() {
  local name="$1" host="$2"
  local txt
  txt=$(dig +short +time=5 TXT "$host" 2>/dev/null | head -1)
  if [[ "$txt" == *enrtree-root* ]]; then
    pass "$name" "enrtree-root present"
  else
    fail "$name" "no enrtree-root TXT record (got: ${txt:-nothing})"
  fi
}

section "Status proxies (stage: $STAGE) — 401 without creds means ALIVE"
if [[ -n "${ETH_RPC_PROXY_USER:-}" ]]; then
  GROUP=RPC_ALIVE rpc "eth-rpc proxy ethereum/mainnet" "https://$STAGE.eth-rpc.status.im/ethereum/mainnet" "200" \
       -u "$ETH_RPC_PROXY_USER:$ETH_RPC_PROXY_PASSWORD"
else
  GROUP=RPC_ALIVE rpc "eth-rpc proxy ethereum/mainnet" "https://$STAGE.eth-rpc.status.im/ethereum/mainnet" "401"
fi
http "eth-rpc proxy puzzle-auth"      "https://$STAGE.eth-rpc.status.im/auth/puzzle" "200"
if [[ -n "${MARKET_PROXY_USER:-}" ]]; then
  http "market proxy leaderboard"     "https://$STAGE.market.status.im/v1/leaderboard/markets" "200" \
       -u "$MARKET_PROXY_USER:$MARKET_PROXY_PASSWORD"
else
  http "market proxy leaderboard"     "https://$STAGE.market.status.im/v1/leaderboard/markets" "401"
fi
GROUP=TOKENLIST_PRIMARY http "market proxy token lists" "https://prod.market.status.im/static/lists.json" "200"
http "market proxy status token list" "https://prod.market.status.im/static/token-list.json" "200"
if [[ -n "${NFT_PROXY_USER:-}" ]]; then
  http "nft proxy (alchemy-compat)"   "https://$STAGE.nft.status.im/ethereum/mainnet/nft/v3/getNFTsForOwner?owner=vitalik.eth&pageSize=1" "200" \
       -u "$NFT_PROXY_USER:$NFT_PROXY_PASSWORD"
else
  http "nft proxy (alchemy-compat)"   "https://$STAGE.nft.status.im/" "401"
fi

section "Waku fleet status.prod (messaging core)"
dns_txt "enrtree DNS discovery"       "boot.prod.status.nodes.status.im"
for dc in do-ams3 gc-us-central1-a ac-cn-hongkong-c; do
  tcp "boot-01.$dc"  "boot-01.$dc.status.prod.status.im"  30303
  tcp "store-01.$dc" "store-01.$dc.status.prod.status.im" 30303
  tcp "store-02.$dc" "store-02.$dc.status.prod.status.im" 30303
done

section "Direct RPC fallbacks (each optional; at least ONE rpc provider must be alive)"
OPT=1 GROUP=RPC_ALIVE rpc "infura mainnet (no token)" "https://mainnet.infura.io/v3/deadbeef" "401,403"
# NOTE: as of 2026-08-28 all *.rpc.grove.city hosts have NO DNS records at all —
# the direct-grove fallback tier in status-go is dead (WARN until config is fixed).
OPT=1 dns_a "grove/pokt eth (fallback tier)" "eth.rpc.grove.city"
OPT=1 GROUP=RPC_ALIVE rpc "zksync era (public)"   "https://mainnet.era.zksync.io" "200"
OPT=1 GROUP=RPC_ALIVE rpc "scroll (public)"       "https://rpc.scroll.io" "200"
OPT=1 GROUP=RPC_ALIVE rpc "bsc dataseed (public)" "https://bsc-dataseed.bnbchain.org" "200"
if [[ "$RPC_ALIVE" -gt 0 ]]; then
  pass "rpc coverage (proxy + fallbacks)" "$RPC_ALIVE provider(s) alive"
else
  fail "rpc coverage (proxy + fallbacks)" "no RPC provider reachable at all"
fi

section "Wallet third-party services"
http "coingecko fallback"             "https://api.coingecko.com/api/v3/ping" "200"
http "rarible (403 without key=alive)" "https://api.rarible.org/v0.1/openapi.json" "200,403"
http "alchemy nft (demo key)"         "https://eth-mainnet.g.alchemy.com/nft/v3/demo/getNFTsForOwner?owner=vitalik.eth&pageSize=1" "200,403,429"
http "li.fi (swap/bridge)"            "https://li.quest/v1/chains" "200"
http "paraswap prices api"            "https://api.paraswap.io/tokens/1" "200"
http "efp (follow protocol)"          "https://data.ethfollow.xyz/api/v1/stats" "200"
http "moonpay widget"                 "https://buy.moonpay.com/" "200"
http "mercuryo currencies"            "https://api.mercuryo.io/v1.6/lib/currencies" "200"
http "4byte.directory (tx decoding)"  "https://www.4byte.directory/api/v1/signatures/?hex_signature=0xa9059cbb" "200"
http "raw.githubusercontent (4byte)"  "https://raw.githubusercontent.com/ethereum-lists/4bytes/master/README.md" "200"

section "Content / media"
if [[ -n "${KLIPY_API_KEY:-}" ]]; then
  http "klipy gifs (functional)"      "https://api.klipy.com/api/v1/$KLIPY_API_KEY/gifs/trending?page=1&per_page=1&customer_id=probe" "200"
else
  http "klipy gifs (liveness)"        "https://api.klipy.com/api/v1/" "204,200,404"
fi
http "ipfs.status.im (stickers/ens/updates)" "https://ipfs.status.im/" "200"
http "pinata gateway (desktop IPFS)"  "https://gateway.pinata.cloud/ipfs/QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn" "200" -L
# ipfs.io is TLS-reset (SNI-blocked?) from some ISPs — a per-region signal.
# Optional when the market proxy token lists are reachable (the primary source).
if [[ "$TOKENLIST_PRIMARY" -gt 0 ]]; then
  OPT=1 http "ipfs.io (uniswap token list)" "https://ipfs.io/ipns/tokens.uniswap.org" "200" -L
else
  http "ipfs.io (uniswap token list)" "https://ipfs.io/ipns/tokens.uniswap.org" "200" -L
fi
http "status.app desktop news RSS"    "https://status.app/desktop-news/rss/v2" "200"

section "Connectivity / misc"
http "walletconnect relay (400=alive)" "https://relay.walletconnect.com/" "400,200"
http "status.app website"             "https://status.app/" "200"
# gorush.infra.status.im: mobile push relay, NOT reachable from public internet — probe only from infra.

if [[ "$JSON" == 1 ]]; then
  printf '{"timestamp":"%s","stage":"%s","failed":%d,"warnings":%d,"checks":[%s]}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$STAGE" "$FAIL" "$WARN" "$RESULTS"
else
  echo
  echo "Failed checks: $FAIL   Warnings (optional fallbacks): $WARN"
fi
exit "$FAIL"
