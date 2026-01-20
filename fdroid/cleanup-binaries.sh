#!/usr/bin/env bash
set -e

# Remove binary files that F-Droid scanner would flag.
find vendor mobile/vendors -type f -print0 | while IFS= read -r -d '' f; do
  if file --mime "$f" | grep -q binary; then
    rm -f "$f"
  fi
done

# Target only corpora/corpus subdirs, not the fuzz/ dir itself: OpenSSL's configure
# walks fuzz/build.info and fails with "No such file or directory" if fuzz/ is gone.
find vendor mobile/vendors -type d \( -name 'corpora' -o -name 'corpus' \) -print0 | xargs -0 rm -rf

# Remove Cargo.toml files without lockfiles that the scanner flags.
find vendor/QR-Code-generator/rust mobile/vendors/openssl/cloudflare-quiche \
  -name "Cargo.toml" -type f -delete

# Remove test/e2e artefacts not needed for the build.
rm -rf test/e2e
rm -f test/e2e_appium/package.json
