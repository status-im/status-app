#!/usr/bin/env bash

set -e pipefail

# Fix rpath and interpreter not fixed by linuxdeployqt
if [[ ! -z "${IN_NIX_SHELL}" ]]; then
	patchelf --set-rpath '$ORIGIN/../../lib' \
    "${APP_DIR}/usr/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so" \
          "${APP_DIR}/usr/lib/libStatusQ.so"

	patchelf --set-rpath '$ORIGIN' \
		"${APP_DIR}/usr/lib/libcom_err.so.3" \
		"${APP_DIR}/usr/lib/libstatus.so"

	patchelf --set-rpath '$ORIGIN/../' \
		"${APP_DIR}"/usr/lib/gstreamer-1.0/* \
		"${APP_DIR}"/usr/lib/nss/*.so

	patchelf --set-rpath '$ORIGIN/../../' "${APP_DIR}"/usr/lib/gstreamer1.0/gstreamer-1.0/*

	patchelf --set-rpath '$ORIGIN/../lib' "${APP_DIR}/usr/libexec/QtWebEngineProcess"

	case "$(uname -m)" in
		aarch64) LD_INTERP=/lib/ld-linux-aarch64.so.1 ;;
		*)       LD_INTERP=/lib64/ld-linux-x86-64.so.2 ;;
	esac

	patchelf --set-interpreter "${LD_INTERP}" \
		"${APP_DIR}/usr/bin/nim_status_client" \
		"${APP_DIR}/usr/libexec/QtWebEngineProcess" \
		"${APP_DIR}/usr/lib/libQt5Core.so.5" \
		"${APP_DIR}"/usr/lib/gstreamer1.0/gstreamer-1.0/*
fi
