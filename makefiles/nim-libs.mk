# The Nim flags of the libraries status-go builds for the app (libsds, libtkl): the
# app's own policy, with each target's optimisation and log level.
LIB_NIM_POLICY := --mm:orc -d:useMalloc --threads:on
LIB_NIM_PARAMS_DESKTOP = $(LIB_NIM_POLICY) --opt:speed -d:chronicles_line_numbers -d:chronicles_log_level=TRACE \
	$(if $(filter true,$(INCLUDE_DEBUG_SYMBOLS)),-d:debug,-d:release)
LIB_NIM_PARAMS_ANDROID := $(LIB_NIM_POLICY) --opt:size -d:release -d:chronicles_log_level=ERROR
LIB_NIM_PARAMS_IOS := $(LIB_NIM_POLICY) --opt:size -d:release -d:chronicles_log_level=ERROR

# The Nim build configuration status-go's make takes: the app's compiler and
# resolution, and the library policy for one target. The target itself goes
# as status-go's own variables (ARCH, ANDROID_API, IPHONE_SDK, ...).
statusgo_nim_config = NIM="$(NIM)" NIMBLE_ROOT="$(NIMBLE_ROOT)" NIM_PARAMS="$(1)"

# A resolved package's directory: $(call nim_pkg_dir,<package name>)
# Windows paths come with (escaped) backslashes and CRLF.
nim_pkg_dir = $(firstword $(shell sed -n -E 's@[\\]+@/@g; s@^--path:"(.*/pkgs2/$(1)-[^/"]*)"[[:space:]]*$$@\1@p' "$(NIMBLE_ROOT)/nimble.paths" 2>/dev/null))
