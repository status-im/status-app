# Nim host tests and benchmarks (test/nim/). Included from the main Makefile;
# relies on NIM_PARAMS, STATUSQ_LIB_PATH, STATUSGO*, QRCODEGEN and the Qt
# variables being defined at the include site.
#
# Naming convention: benchmarks end in `_bench.nim`; everything else is a test.

NIM_BENCH_FILES := $(wildcard test/nim/*_bench.nim)
NIM_TEST_FILES := $(filter-out $(NIM_BENCH_FILES),$(wildcard test/nim/*.nim))
NIM_TESTS := $(addprefix nim-test-run/,$(NIM_TEST_FILES))
NIM_BENCHES := $(addprefix nim-test-run/,$(NIM_BENCH_FILES))

# These stand up real StatusQ machinery — signal_handler /
# statusq_invoke_method_queued, ModelQuery/ModelUtils, SFPM proxy chains, or
# full modal QML trees in an offscreen engine — so they link libStatusQ and
# need it built first.
NIM_TESTS_LINK_STATUSQ := \
	asset_proxy_chain_bench \
	browser_section_open_url_test \
	chat_search_model_bulk_load_test \
	chat_search_model_proxy_test \
	chat_search_model_test \
	collectibles_request_ids_test \
	collectibles_selector_bench \
	collectibles_selector_model_bench \
	community_accept_request_test \
	community_permission_save_test \
	contact_info_requests_test \
	input_area_text_send_test \
	message_history_paging_test \
	message_loading_isolation_test \
	notification_conversation_read_test \
	send_handler_adaptors_bench \
	send_handler_lookup_bench \
	send_modal_instantiation_bench \
	services_pause_bridge_test \
	share_intake_wake_test \
	signal_handler_test \
	section_unread_counts_test \
	thread_edit_service_test \
	swap_key_harvest_bench \
	swap_modal_instantiation_bench \
	thread_navigation_test \
	thread_notifications_test \
	thread_search_test \
	thread_section_badges_test \
	token_selector_module_test \
	typed_completion_test \
	url_scheme_event_test \
	wallet_connect_controller_test

NIM_STATUSQ_TARGETS := $(patsubst %,nim-test-run/test/nim/%.nim,$(NIM_TESTS_LINK_STATUSQ))
$(NIM_STATUSQ_TARGETS): NIM_PARAMS += --passL:"-L$(STATUSQ_LIB_PATH)" --passL:"-lStatusQ"
$(NIM_STATUSQ_TARGETS): | statusq

nim-test-run/test/nim/thread_search_test.nim: export FLAG_THREADS_ENABLED := 1
nim-test-run/test/nim/thread_section_badges_test.nim: export FLAG_THREADS_ENABLED := 1

nim-test-run/test/nim/thread_notifications_test.nim: export FLAG_THREADS_ENABLED := 1
# The messages module also imports the existing keycard service bindings.
NIM_TESTS_LINK_KEYCARD := thread_navigation_test thread_search_test thread_notifications_test thread_section_badges_test
NIM_KEYCARD_TARGETS := $(patsubst %,nim-test-run/test/nim/%.nim,$(NIM_TESTS_LINK_KEYCARD))
$(NIM_KEYCARD_TARGETS): NIM_PARAMS += --passL:"-L$(STATUSKEYCARD_QT_LIBDIR)" --passL:"-l$(STATUSKEYCARD_QT_LINKNAME)"
$(NIM_KEYCARD_TARGETS): | $(STATUSKEYCARD_QT_LIB)

ifeq ($(mkspecs),linux)
$(NIM_KEYCARD_TARGETS): export LD_LIBRARY_PATH := $(shell pkg-config --variable=libdir libpcsclite):$(LD_LIBRARY_PATH)
endif

nim-test-run/test/nim/qrscan_zxing_errors_test.nim: NIM_PARAMS += -d:qrscanZxingLib="$(abspath $(ZXING))"
nim-test-run/test/nim/qrscan_zxing_errors_test.nim: | $(ZXING)
# Loads resources.rcc (the bundled NimQtCamera/NimQrScan modules).
nim-test-run/test/nim/qml_libs_resources_test.nim: | rcc

# Model-spy tests call inspection accessors gated behind
# `when defined(testing) or defined(QT_MODEL_SPY)` or assert on the granular
# signals model_sync records only under QT_MODEL_SPY. The define is applied
# per-file, NOT globally
NIM_TESTS_MODEL_SPY := \
	admin_members_test \
	all_tokens_view_test \
	assets_adaptor_model_test \
	chat_search_model_bulk_load_test \
	chat_search_model_proxy_test \
	collectibles_model_test \
	collectibles_selector_model_test \
	community_roster_model_test \
	grouped_account_assets_model_test \
	market_leaderboard_model_test \
	member_model_test \
	model_sync_move_test \
	model_sync_unified_test \
	token_groups_model_test \
	token_lists_model_test \
	token_selector_model_bench \
	token_selector_model_test \
	token_selector_module_test \
	token_selector_producer_view_test

NIM_MODEL_SPY_TARGETS := $(patsubst %,nim-test-run/test/nim/%.nim,$(NIM_TESTS_MODEL_SPY))
$(NIM_MODEL_SPY_TARGETS): NIM_PARAMS += -d:QT_MODEL_SPY

# Most tests build and run as two programs, so the modules they share are
# compiled and linked once:
#   main    - built with QT_MODEL_SPY and StatusQ, which the other tests tolerate
#   threads - the thread tests: they turn the threads feature flag on for the process
# NIM_TESTS_MERGE=0 builds every test as its own program.
NIM_TESTS_MERGE ?= 1
NIM_MERGED_GROUPS := main threads
nim_test_paths = $(patsubst %,test/nim/%.nim,$1)
nim_merged_file = build/nim-tests/merged_$1_tests.nim
nim_merged_target = nim-test-run/$(call nim_merged_file,$1)

# Kept apart: a define or resource of their own, or a GUI application object.
NIM_OWN_PROGRAM := $(call nim_test_paths,qml_libs_resources_test qrscan_zxing_errors_test) \
	$(shell grep -lE 'newQ(Gui)?Application|QQmlApplicationEngine' $(NIM_TEST_FILES))
# Found by what they read, so a new test of the threads flag joins this program.
NIM_MERGED_threads := $(filter-out $(NIM_OWN_PROGRAM),$(shell grep -l 'THREADS_ENABLED' $(NIM_TEST_FILES)))
NIM_MERGED_main := $(filter-out $(NIM_OWN_PROGRAM) $(NIM_MERGED_threads),$(NIM_TEST_FILES))
NIM_MERGED_TARGETS := $(foreach g,$(NIM_MERGED_GROUPS),$(call nim_merged_target,$g))

ifeq ($(NIM_TESTS_MERGE),1)
 NIM_TESTS_RUN := $(addprefix nim-test-run/,$(filter $(NIM_OWN_PROGRAM),$(NIM_TEST_FILES))) $(NIM_MERGED_TARGETS)
else
 NIM_TESTS_RUN := $(NIM_TESTS)
endif

$(NIM_MERGED_TARGETS): NIM_PARAMS += --passL:"-L$(STATUSQ_LIB_PATH)" --passL:"-lStatusQ"
$(NIM_MERGED_TARGETS): | statusq
NIM_MODEL_SPY_TARGETS += $(call nim_merged_target,main)
$(call nim_merged_target,main): NIM_PARAMS += -d:QT_MODEL_SPY
$(call nim_merged_target,threads): export FLAG_THREADS_ENABLED := 1
$(call nim_merged_target,threads): NIM_PARAMS += --passL:"-L$(STATUSKEYCARD_QT_LIBDIR)" --passL:"-l$(STATUSKEYCARD_QT_LINKNAME)"
$(call nim_merged_target,threads): | $(STATUSKEYCARD_QT_LIB)
ifeq ($(mkspecs),linux)
$(call nim_merged_target,threads): export LD_LIBRARY_PATH := $(shell pkg-config --variable=libdir libpcsclite):$(LD_LIBRARY_PATH)
endif

# Each program is a file of imports, written on every run so it follows test/nim/.
define nim_write_merged
{ echo '{.warning[UnusedImport]: off.}'; printf 'import "../../%s"\n' $(basename $(NIM_MERGED_$1)); } > $(call nim_merged_file,$1)
endef
$(NIM_MERGED_TARGETS): | nim-merged-tests nim-tests-qt-app
nim-merged-tests:
	mkdir -p build/nim-tests
	$(foreach g,$(NIM_MERGED_GROUPS),$(call nim_write_merged,$g);)
.PHONY: nim-merged-tests

# A test that creates a QCoreApplication of its own destroys the one the merged tests share.
nim-tests-qt-app:
	@own=$$(grep -lE 'QCoreApplication\.create' $(NIM_TEST_FILES)); \
	if [ -n "$$own" ]; then \
		echo "These tests create their own QCoreApplication:"; echo "$$own"; \
		echo "Use ensureQtCoreApp() from test/nim/support/qt_app.nim instead."; \
		exit 1; \
	fi
.PHONY: nim-tests-qt-app

ifneq ($(mkspecs),win32)
nim-test-run/%: NIM_PARAMS += --passL:"$(QT_SEAQT_EXTRA_LIBS)"
endif

# Per-test nimcache by default so parallel test builds don't race.
# NIM_TESTS_SHARED_CACHE=1 shares one cache.
NIMCACHE_BASE ?= $(or $(WORKSPACE_TMP),build)/nimcache
# Nim does not invalidate cached C/C++ objects when GCC changes. LTO objects
# must be compiled and linked with compatible compiler versions.
ifeq ($(mkspecs),linux)
 NIM_TEST_CACHE_TOOLCHAIN := -$(shell gcc -dumpmachine)-gcc$(shell gcc -dumpfullversion)-gxx$(shell g++ -dumpfullversion)
endif
ifeq ($(NIM_TESTS_SHARED_CACHE),1)
 nim_test_cache = $(if $(filter $(NIM_MODEL_SPY_TARGETS),$1),shared-spy,shared)$(if $(filter $(NIM_BENCHES),$1),-bench)
else
 nim_test_cache = $(notdir $(basename $1))
endif
nim-test-run/%: NIM_PARAMS += --nimcache:$(NIMCACHE_BASE)-$(call nim_test_cache,$@)$(NIM_TEST_CACHE_TOOLCHAIN)

# Windows links the sds/status import libraries by explicit path
# (NIM_EXTRA_PARAMS); status-go's build can delete an earlier sds.lib, so wait
# for the import libraries like the client does.
ifeq ($(mkspecs),win32)
 NIM_TEST_ORDER_DEPS := $(WIN_IMPORT_LIBS)
endif
# Tests build without LTO, which only lengthens their links; the benchmarks keep the application's flags.
$(NIM_TESTS) $(NIM_MERGED_TARGETS): NIM_TEST_DROP := -d:lto

nim-test-run/%: | qt-pkgconfig $(STATUSGO) $(QRCODEGEN) $(NIM_TEST_ORDER_DEPS)
	LD_LIBRARY_PATH="$(QT_LIBDIR)":"$(NIMSDS_LIBDIR)":"$(STATUSGO_LIBDIR)":"$(STATUSKEYCARD_QT_LIBDIR)":"$(EXTRA_LIBS_PATH)":"$(LD_LIBRARY_PATH)" $(ENV_SCRIPT) \
	nim c $(filter-out $(NIM_TEST_DROP),$(NIM_PARAMS)) $(NIM_EXTRA_PARAMS) --mm:orc --passL:"-L$(STATUSGO_LIBDIR)" --passL:"-lstatus" --passL:"$(QRCODEGEN)" -r $(subst nim-test-run/,,$@)

tests-nim: $(NIM_TESTS_RUN)

benches-nim: $(NIM_BENCHES)

# CI target (ci/Jenkinsfile.tests-nim). Deliberately runs the benchmarks too:
# their setup code and structural GREEN-gate assertions only stay honest if CI
# keeps building and executing them. Wall-clock perf gates flake on the shared
# executors, so BENCH_ASSERTS=0 downgrades them to report-only, and BENCH_QUICK=1
# trims the size sweeps to the assert-relevant sizes (see
# test/nim/benchmarks/perf_gate.nim).
# -j1 sub-make with shared nimcache: one test at a time, reusing C objects across tests.
tests-nim-linux: export BENCH_ASSERTS := 0
tests-nim-linux: export BENCH_QUICK := 1
tests-nim-linux:
	+ "$(MAKE)" --no-print-directory -j1 NIM_TESTS_SHARED_CACHE=1 tests-nim benches-nim
