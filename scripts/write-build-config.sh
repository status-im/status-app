#!/usr/bin/env bash
# Writes build-config (src/build_config.nim) from the STATUS_BUILD_* environment variables,
# encrypted with the key compiled into the app: STATUS_CONFIG_KEY, or the key
# in STATUS_CONFIG_SEALED_KEY unsealed with STATUS_CONFIG_PRIVATE_KEY.
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

KEY="${STATUS_CONFIG_KEY}"
if [[ -z "${KEY}" && -n "${STATUS_CONFIG_SEALED_KEY}" ]]; then
    KEY="$(openssl pkeyutl -decrypt -inkey "${STATUS_CONFIG_PRIVATE_KEY}" -in "${STATUS_CONFIG_SEALED_KEY}" \
        -pkeyopt rsa_padding_mode:oaep -pkeyopt rsa_oaep_md:sha256)"
fi

JSON="$(printf '{\n%s\n}\n' "${ENTRIES}")"
if [[ -n "${KEY}" ]]; then
    IV="$(openssl rand -hex 16)"
    echo "${IV}:$(openssl enc -aes-256-ctr -K "${KEY}" -iv "${IV}" -a -A <<< "${JSON}")" > "${OUTPUT}"
else
    echo "${JSON}" > "${OUTPUT}"
fi
chmod 644 "${OUTPUT}"
echo "Wrote ${COUNT} values to ${OUTPUT}"
