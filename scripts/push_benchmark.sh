#!/usr/bin/env bash

export YLW='\033[1;33m'
export RED='\033[0;31m'
export GRN='\033[0;32m'
export BLU='\033[0;34m'
export BLD='\033[1m'
export RST='\033[0m'

# Clear line
export CLR='\033[2K'

set -o nounset
set -o errexit
set -o pipefail

REPO_URL="git@github.com:status-im/status-app-benchmarks.git"

GIT_ROOT=$(cd "${BASH_SOURCE%/*}" && git rev-parse --show-toplevel)

echo -e "${GRN}Pushing benchmark results${RST}"

cd "${GIT_ROOT}"
# GIT_REF selects test code; SOURCE_COMMIT identifies the binary under test.
pr_number="${PR_NUMBER:-${CHANGE_ID:-}}"
release_version="${RELEASE_VERSION:-}"
if [[ -z "${SOURCE_COMMIT:-}" && ( -n "${pr_number}" || -n "${release_version}" ) ]]; then
  echo "Cannot derive the binary commit from BUILD_SOURCE"
  exit 2
fi
commit_sha="${SOURCE_COMMIT:-$(git rev-parse --short HEAD)}"
source_ref="${GIT_REF:-$(git rev-parse --abbrev-ref HEAD)}"
build_source="${BUILD_SOURCE:-}"

if [[ -n "${pr_number}" && -n "${release_version}" ]]; then
  echo "Set CHANGE_ID or RELEASE_VERSION, not both"
  exit 2
fi

if [[ -n "${pr_number}" ]]; then
  channel=pr
elif [[ -n "${release_version}" ]]; then
  channel=release
else
  channel="${CHANNEL:-nightly}"
fi

if [[ "${channel}" == "release" ]]; then
  if [[ "${release_version}" =~ ^([0-9]+\.[0-9]+) ]]; then
    release_series="${BASH_REMATCH[1]}"
  else
    echo "Cannot derive release series from ${release_version}"
    exit 2
  fi
else
  release_series=""
fi

git clone "${REPO_URL}" benchmarks-repo
cd benchmarks-repo

date_time=$(date -u '+%Y-%m-%dT%H:%M:%S')
date_compact=$(date -u '+%Y%m%dT%H%M%S')
build_number="${BUILD_NUMBER:-${date_compact}}"

case "${channel}" in
  nightly)
    data_dir="./data"
    output_dir="./docs/desktop/nightly"
    build_label="${date_time}|${commit_sha}"
    run_id="nightly-${commit_sha}-${build_number}"
    ;;
  pr)
    [[ "${pr_number}" =~ ^[0-9]+$ ]] || { echo "CHANGE_ID is required for PR benchmarks"; exit 2; }
    data_dir="./data/desktop/pr/${pr_number}"
    output_dir="./docs/desktop/pr/${pr_number}"
    build_label="PR ${pr_number}"
    run_id="pr-${pr_number}-${commit_sha}-${build_number}"
    ;;
  release)
    [[ -n "${release_version}" ]] \
      || { echo "RELEASE_VERSION is required for release benchmarks"; exit 2; }
    data_dir="./data/desktop/releases/${release_series}"
    output_dir="./docs/desktop/releases/${release_series}"
    build_label="${release_version}"
    run_id="release-${release_version}-${commit_sha}-${build_number}"
    ;;
  *)
    echo "Unsupported benchmark channel: ${channel}"
    exit 2
    ;;
esac

echo -e "${GRN}Creating virtual environment${RST}"
python3 -m venv .venv
source .venv/Scripts/activate
PYTHON_CMD=".venv/Scripts/python.exe"

echo -e "${GRN}Installing dependencies${RST}"
${PYTHON_CMD} -m  pip install --upgrade pip
${PYTHON_CMD} -m  pip install -r requirements.txt

echo -e "${GRN}Collecting Windows system info${RST}"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/collect_machine_info.ps1 -OutputPath machine_info.json \
  || echo -e "${YLW}Warning: failed to collect system info — continuing without it${RST}"

machine_info_args=()
[[ -s machine_info.json ]] && machine_info_args=(--machine-info machine_info.json)

echo -e "${GRN}Updating data in repo${RST}"
results_dir="../test/e2e/benchmark-results"
if [[ ! -d "${results_dir}" ]]; then
  echo -e "${YLW}Structured benchmark results not found; falling back to Allure${RST}"
  results_dir="../test/e2e/allure-report"
fi
parse_args=(
  --config ./scripts/tests_config.toml
  parse "${results_dir}"
  --data-dir ./data
  --run-id "${run_id}"
  --channel "${channel}"
  --commit-hash "${commit_sha}"
  --date "${date_time}"
  --build-label "${build_label}"
  --source-ref "${source_ref}"
  --build-source "${build_source}"
)
[[ -n "${pr_number}" ]] && parse_args+=(--pr-number "${pr_number}")
[[ -n "${release_version}" ]] && parse_args+=(--release-version "${release_version}")
parse_args+=("${machine_info_args[@]}")
${PYTHON_CMD} scripts/benchmark.py "${parse_args[@]}"

echo -e "${GRN}Generating new visualizations from data${RST}"
${PYTHON_CMD} scripts/benchmark.py --config ./scripts/tests_config.toml graphs \
  --data-dir "${data_dir}" \
  --output-dir "${output_dir}" \
  --channel "${channel}" \
  --baseline-dir ./data/desktop/baselines

echo -e "${GRN}Committing changes${RST}"
rm -f machine_info.json
git add .
git commit -m "Add ${channel} benchmark results for ${build_label}"

echo -e "${GRN}Pushing changes${RST}"
git push "${REPO_URL}"

echo -e "${GRN}Push finished${RST}"
