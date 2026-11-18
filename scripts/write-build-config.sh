#!/usr/bin/env bash
# Writes build-config.json (src/build_config.nim) from the STATUS_BUILD_* environment variables.
set -eo pipefail

[[ $# -ne 1 ]] && { echo 'write-build-config.sh <output_file>' >&2; exit 1; }

OUTPUT="${1}"
PREFIX='STATUS_BUILD_'

ENTRIES=''
COUNT=0
for NAME in $(compgen -v "${PREFIX}" | LC_ALL=C sort); do
    VALUE="${!NAME}"
    [[ -z "${VALUE}" ]] && continue
    if [[ "${VALUE}" == *[[:cntrl:]]* ]]; then
        echo "${NAME} contains a control character." >&2
        exit 1
    fi
    VALUE="${VALUE//\\/\\\\}"
    VALUE="${VALUE//\"/\\\"}"
    ENTRIES+="${ENTRIES:+,$'\n'}  \"${NAME#"${PREFIX}"}\": \"${VALUE}\""
    COUNT=$((COUNT + 1))
done

rm -f "${OUTPUT}"

if [[ ${COUNT} -eq 0 ]]; then
    echo "No ${PREFIX}* variables are set: no build config file written."
    exit 0
fi

printf '{\n%s\n}\n' "${ENTRIES}" > "${OUTPUT}"
chmod 644 "${OUTPUT}"
echo "Wrote ${COUNT} values to ${OUTPUT}"
