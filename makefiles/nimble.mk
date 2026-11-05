# Nim packages and compiler, resolved by nimble from nim_status_client.nimble
# and nimble.lock, and the Nim build configuration handed to status-go.
# Included by the root Makefile; mobile/Makefile includes nim-libs.mk only.

# nimble >= 0.26.2. Packages, the compiler included, go to nimbledeps/
# (--localdeps): a global store install drops a package's installFiles.
NIMBLE ?= nimble

NIMBLE_ROOT := $(CURDIR)

nimble.paths: nim_status_client.nimble nimble.lock
	echo -e $(BUILD_MSG) "Nim packages (nimble setup)"
	env -u SDKROOT -u CPATH -u LIBRARY_PATH -u ANDROID_NDK_ROOT -u NIMBLE_DIR "$(NIMBLE)" -y setup --localdeps > .nimble-setup.log 2>&1 || { \
		cat .nimble-setup.log >&2; exit 1; }
	touch $@

nimble-deps: nimble.paths

# The compiler the manifest pins, as nimble set it up, else the one on PATH
# (nimble only uses a system Nim that satisfies the pin). Expanded when used,
# so after nimble.paths is made.
NIM_VERSION := $(shell sed -n -E 's/^requires "nim == ([^"]+)".*/\1/p' nim_status_client.nimble)
NIM ?= $(or $(firstword $(wildcard $(CURDIR)/nimbledeps/pkgs2/nim-$(NIM_VERSION)-*/bin/nim $(CURDIR)/nimbledeps/pkgs2/nim-$(NIM_VERSION)-*/bin/nim.exe)),nim)
export NIM

include makefiles/nim-libs.mk
