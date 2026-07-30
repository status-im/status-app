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
	collectibles_selector_bench \
	collectibles_selector_model_bench \
	send_handler_adaptors_bench \
	send_handler_lookup_bench \
	send_modal_instantiation_bench \
	signal_handler_test \
	swap_key_harvest_bench \
	swap_modal_instantiation_bench \
	typed_completion_test \
	url_scheme_event_test

NIM_STATUSQ_TARGETS := $(patsubst %,nim-test-run/test/nim/%.nim,$(NIM_TESTS_LINK_STATUSQ))
$(NIM_STATUSQ_TARGETS): NIM_PARAMS += --passL:"-L$(STATUSQ_LIB_PATH)" --passL:"-lStatusQ"
$(NIM_STATUSQ_TARGETS): | statusq

# Model-spy tests call inspection accessors gated behind
# `when defined(testing) or defined(QT_MODEL_SPY)` or assert on the granular
# signals model_sync records only under QT_MODEL_SPY. The define is applied
# per-file, NOT globally
NIM_TESTS_MODEL_SPY := \
	assets_adaptor_model_test \
	collectibles_selector_model_test \
	grouped_account_assets_model_test \
	model_sync_move_test \
	model_sync_unified_test \
	token_groups_model_test \
	token_selector_model_bench \
	token_selector_model_test \
	token_selector_producer_view_test

$(patsubst %,nim-test-run/test/nim/%.nim,$(NIM_TESTS_MODEL_SPY)): NIM_PARAMS += -d:QT_MODEL_SPY

ifneq ($(mkspecs),win32)
nim-test-run/%: NIM_PARAMS += --passL:"$(QT_SEAQT_EXTRA_LIBS)"
endif

nim-test-run/%: | qt-pkgconfig $(STATUSGO) $(QRCODEGEN)
	LD_LIBRARY_PATH="$(QT_LIBDIR)":"$(NIMSDS_LIBDIR)":"$(STATUSGO_LIBDIR)":"$(EXTRA_LIBS_PATH)":"$(LD_LIBRARY_PATH)" $(ENV_SCRIPT) \
	nim c $(NIM_PARAMS) $(NIM_EXTRA_PARAMS) --mm:orc --passL:"-L$(STATUSGO_LIBDIR)" --passL:"-lstatus" --passL:"$(QRCODEGEN)" -r $(subst nim-test-run/,,$@)

tests-nim: $(NIM_TESTS)

benches-nim: $(NIM_BENCHES)

# CI target (ci/Jenkinsfile.tests-nim). Deliberately runs the benchmarks too:
# their setup code and structural GREEN-gate assertions only stay honest if CI
# keeps building and executing them. Wall-clock perf gates flake on the shared
# executors, so BENCH_ASSERTS=0 downgrades them to report-only (see
# test/nim/benchmarks/perf_gate.nim).
tests-nim-linux: export BENCH_ASSERTS := 0
tests-nim-linux: tests-nim benches-nim
