#!/usr/bin/env bash
# Shared library dependency helpers for packaging (AppImage & Flatpak).

# Native libraries built from source (status-go, keycard, sds, nwaku)
copy_native_libs() {
  local dest="$1"
  echo "Bundling native libraries..."
  cp -P vendor/status-go/build/bin/libstatus.so* "$dest/"
  local keycard="${STATUSKEYCARDGO:-vendor/status-keycard-go/build/libkeycard/libkeycard.so}"
  if [[ -f "$keycard" ]]; then
    cp -P "$keycard" "$dest/"
  fi
  if [[ -f "${NIM_SDS_SOURCE_DIR:-.}/build/libsds.so" ]]; then
    cp -P "${NIM_SDS_SOURCE_DIR:-.}/build/libsds.so" "$dest/"
  fi
  if [[ "${USE_NWAKU:-}" == "true" ]]; then
    cp "${NWAKU_SOURCE_DIR:-.}/build/libwaku.so" "$dest/"
  fi
}

# System libraries from Ubuntu build environment (GStreamer, NSS, PC/SC)
copy_system_libs() {
  local dest="$1"
  echo "Bundling system libraries..."
  cp -P /usr/lib/x86_64-linux-gnu/libgst*.so* "$dest/"
  cp -r /usr/lib/x86_64-linux-gnu/gstreamer-1.0 "$dest/"
  cp -r /usr/lib/x86_64-linux-gnu/nss "$dest/"
  cp -P /usr/local/lib/x86_64-linux-gnu/libpcsclite*.so* "$dest/"
}
