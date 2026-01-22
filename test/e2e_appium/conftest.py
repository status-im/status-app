import multiprocessing
import os
import time
from datetime import datetime
from pathlib import Path
from typing import Any, List, Optional

import pytest

from .config import get_config, setup_logging, log_test_start, log_test_end
from .config.logging_config import get_logger, LoggingConfig
from .utils.screenshot import save_screenshot, save_page_source
from core.stash_keys import MULTI_DEVICE_MANAGERS_KEY
from core.capacity_reserver import set_shared_pending_counter
from core.shared_counter import FileBasedCounter, create_shared_counter


# Expose fixture modules without star imports
pytest_plugins = [
    "fixtures.onboarding_fixture",
    "fixtures.multi_device_fixtures",
]


# Note: Device attachment is now handled by StepMixin._init_devices() called in tests
# The autouse fixture was removed due to async event loop conflicts with request.getfixturevalue()


_logging_setup = None
_saved_failure_logs: List[Path] = []
_bs_pending_counter = None
_counter_manager: Optional[Any] = None


def _extract_summary_details(test_report) -> dict[str, str | int | None]:
    result = {"path": None, "lineno": None, "message": "Unknown error"}

    longrepr = getattr(test_report, "longrepr", None)
    if not longrepr:
        return result

    reprcrash = getattr(longrepr, "reprcrash", None)
    if reprcrash:
        result["path"] = getattr(reprcrash, "path", None)
        result["lineno"] = getattr(reprcrash, "lineno", None)
        message = getattr(reprcrash, "message", None)
        if message:
            result["message"] = message
            return result

        if isinstance(reprcrash, tuple) and len(reprcrash) >= 3:
            result["message"] = reprcrash[2]
            return result

    longreprtext = getattr(longrepr, "longreprtext", None)
    if longreprtext:
        last_line = _last_nonempty_line(longreprtext)
        if last_line:
            result["message"] = last_line
            return result

    last_line = _last_nonempty_line(str(longrepr))
    if last_line:
        result["message"] = last_line

    return result


def _last_nonempty_line(text: str) -> str | None:
    text = (text or "").strip()
    if not text:
        return None

    for line in reversed(text.splitlines()):
        line = line.strip()
        if line:
            return line

    return None


def pytest_configure(config):
    global _logging_setup, _counter_manager
    config_obj: Optional[Any] = None

    # Normalize CLI --env to CURRENT_TEST_ENVIRONMENT so all components agree
    try:
        cli_env = getattr(config.option, "env", None)
        if cli_env:
            os.environ["CURRENT_TEST_ENVIRONMENT"] = cli_env
            os.environ["TEST_ENVIRONMENT"] = cli_env
    except Exception:
        # Do not block test runs if normalization fails
        pass

    try:
        config_obj = get_config(refresh=True)

        reports_dir = Path(config_obj.reports_dir)
        logs_dir = Path(config_obj.logs_dir)
        enable_xml_report = config_obj.enable_xml_report
        enable_html_report = config_obj.enable_html_report

        logging_cfg = LoggingConfig(
            logs_dir=str(logs_dir),
            console_level=config_obj.logging_level,
            file_level=config_obj.logging_level,
        )
        _logging_setup = setup_logging(logging_cfg)

        logger = get_logger("conftest")
        logger.info(
            "Using reports directory from %s config: %s",
            config_obj.environment_name,
            reports_dir,
        )

    except Exception as e:
        # Simplified fallback using defaults
        reports_dir = Path("reports")
        enable_xml_report = True
        enable_html_report = True

        _logging_setup = setup_logging()

        logger = get_logger("conftest")
        logger.warning("Using default configuration: %s", e)
        logger.warning("Ensure YAML config files are properly set up")

    reports_dir.mkdir(parents=True, exist_ok=True)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    if not hasattr(config.option, "xmlpath") or not config.option.xmlpath:
        if enable_xml_report:
            xml_report = reports_dir / f"pytest_results_{timestamp}.xml"
            config.option.xmlpath = str(xml_report)

    if not hasattr(config.option, "htmlpath") or not config.option.htmlpath:
        if enable_html_report:
            html_report = reports_dir / f"pytest_report_{timestamp}.html"
            config.option.htmlpath = str(html_report)
            config.option.self_contained_html = True

    logger = _logging_setup["loggers"]["main"] if _logging_setup else None
    if logger:
        logger.info("Automatic report generation enabled:")
        if hasattr(config.option, "xmlpath") and config.option.xmlpath:
            logger.info("  XML report: %s", config.option.xmlpath)
        if hasattr(config.option, "htmlpath") and config.option.htmlpath:
            logger.info("  HTML report: %s", config.option.htmlpath)

    global _bs_pending_counter, _counter_manager

    if not hasattr(config, "workerinput"):
        # Main process: create file-based shared counter
        try:
            config_obj = get_config()
            base_dir = Path(config_obj.reports_dir).parent / ".shared"
        except Exception:
            base_dir = Path("reports") / ".shared"
        
        counter = create_shared_counter(base_dir=base_dir)
        _bs_pending_counter = counter
        _counter_manager = None
        set_shared_pending_counter(counter)
    else:
        # Worker process: create counter pointing to same file
        counter_path = config.workerinput.get("bs_pending_counter_path")
        if counter_path:
            counter = FileBasedCounter(Path(counter_path), initial_value=0)
            _bs_pending_counter = counter
            set_shared_pending_counter(counter)
        else:
            _bs_pending_counter = None
            set_shared_pending_counter(None)


def pytest_addoption(parser):
    parser.addoption(
        "--env",
        action="store",
        default="browserstack",
        help="Test environment defined in config/environments (e.g. local, browserstack)",
    )


@pytest.fixture(scope="session")
def test_environment(request):
    return request.config.getoption("--env")


def pytest_configure_node(node):
    """Share counter file path with worker nodes."""
    if _bs_pending_counter is not None and hasattr(_bs_pending_counter, "_file_path"):
        node.workerinput["bs_pending_counter_path"] = str(_bs_pending_counter._file_path)


def pytest_unconfigure(config):
    """Cleanup shared counter."""
    set_shared_pending_counter(None)
    globals()["_bs_pending_counter"] = None
    global _counter_manager
    _counter_manager = None


@pytest.fixture(scope="function")
def performance_tracker(request):
    if not _logging_setup:
        return None

    tracker = _logging_setup["performance_tracker"]()

    if hasattr(tracker, "context"):
        tracker.context = tracker.context or {}
        tracker.context.update(
            {
                "test_name": request.node.name,
                "test_module": request.node.module.__name__
                if request.node.module
                else "unknown",
            }
        )

    return tracker


def pytest_runtest_setup(item):
    test_name = item.name
    test_file = item.location[0] if item.location else "unknown"

    log_test_start(
        test_name,
        test_file=test_file,
        markers=[mark.name for mark in item.iter_markers()],
    )


def pytest_collection_modifyitems(config, items):
    """Automatically add single_device marker to tests with device_count(1)."""
    for item in items:
        # Check if test has device_count marker with value 1
        device_count_marker = item.get_closest_marker("device_count")
        if device_count_marker:
            # Extract count from marker args or kwargs
            count = None
            if device_count_marker.args:
                count = device_count_marker.args[0]
            elif "count" in device_count_marker.kwargs:
                count = device_count_marker.kwargs["count"]
            elif "value" in device_count_marker.kwargs:
                count = device_count_marker.kwargs["value"]
            
            # If count is 1, add single_device marker
            if count == 1:
                item.add_marker(pytest.mark.single_device)


def pytest_runtest_teardown(item, nextitem):
    test_name = item.name

    # Determine test success from the test result
    success = True
    duration_ms = 0

    if hasattr(item, "rep_call"):
        success = item.rep_call.passed

    if hasattr(item, "_test_start_time"):
        duration = datetime.now() - item._test_start_time
        duration_ms = int(duration.total_seconds() * 1000)

    log_test_end(test_name, success, duration_ms)
    _apply_test_cooldown(item)


def _apply_test_cooldown(item) -> None:
    env_name = getattr(item.config, "getoption", lambda *_: None)("--env")
    if env_name != "browserstack":
        return

    cooldown_raw = os.getenv("TEST_COOLDOWN_SECONDS", "0")
    try:
        cooldown_seconds = float(cooldown_raw)
    except (TypeError, ValueError):
        cooldown_seconds = 0.0

    if cooldown_seconds <= 0:
        return

    logger = get_logger("conftest")
    logger.debug("Cooldown after test: %.1fs", cooldown_seconds)
    time.sleep(cooldown_seconds)


@pytest.hookimpl(tryfirst=True, hookwrapper=True)
def pytest_runtest_makereport(item, call):
    outcome = yield
    rep = outcome.get_result()

    setattr(item, "rep_" + rep.when, rep)

    if rep.when == "call":
        logger = get_logger("conftest")
        if hasattr(item, "stash"):
            stash_entries = item.stash.get(MULTI_DEVICE_MANAGERS_KEY, [])
            if not stash_entries:
                logger.debug(
                    "Multi-device hook (call phase): stash not yet populated; will retry in teardown"
                )
        else:
            logger.debug("Multi-device hook (call phase) skipped: item has no stash attribute")
        return

    # Perform final reporting during teardown, after fixtures have finished
    if rep.when != "teardown":
        return

    if not hasattr(item, "stash"):
        logger = get_logger("conftest")
        logger.debug("Multi-device hook skipped in teardown: item has no stash attribute")
        return

    stash_entries = item.stash.get(MULTI_DEVICE_MANAGERS_KEY, [])
    if not stash_entries:
        logger = get_logger("conftest")
        logger.debug("Multi-device hook skipped in teardown: no multi_device_managers in stash")
        return

    import asyncio
    from core.session_manager import SessionManager
    logger = get_logger("conftest")

    rep_setup = getattr(item, "rep_setup", None)
    rep_call = getattr(item, "rep_call", None)
    rep_teardown = getattr(item, "rep_teardown", None)

    failure_report = None
    skipped_report = None
    for report in (rep_setup, rep_call, rep_teardown):
        if report and report.failed:
            failure_report = report
            break
        if report and report.skipped and skipped_report is None:
            skipped_report = report

    global_failed = failure_report is not None
    global_skipped = (not global_failed) and skipped_report is not None
    global_reason = None
    if global_failed and failure_report and failure_report.longrepr:
        try:
            reprcrash = getattr(failure_report.longrepr, "reprcrash", None)
            global_reason = getattr(reprcrash, "message", None) if reprcrash else None
            if not global_reason:
                global_reason = str(failure_report.longrepr)
        except Exception:
            global_reason = str(failure_report.longrepr)
    elif global_skipped and skipped_report and skipped_report.longrepr:
        try:
            reprcrash = getattr(skipped_report.longrepr, "reprcrash", None)
            global_reason = getattr(reprcrash, "message", None) if reprcrash else None
            if not global_reason:
                global_reason = str(skipped_report.longrepr)
        except Exception:
            global_reason = str(skipped_report.longrepr)

    for session_managers, pool, environment in stash_entries:
        # Always cleanup (all environments)
        try:
            try:
                loop = asyncio.get_running_loop()
                loop_running = True
            except RuntimeError:
                loop = asyncio.get_event_loop()
                loop_running = False

            if loop_running:
                cleanup_loop = asyncio.new_event_loop()
                try:
                    cleanup_loop.run_until_complete(pool.cleanup())
                    logger.debug("Completed cleanup for pool (env=%s)", environment)
                finally:
                    cleanup_loop.close()
            else:
                if loop.is_closed():
                    loop = asyncio.new_event_loop()
                    asyncio.set_event_loop(loop)
                loop.run_until_complete(pool.cleanup())
                logger.debug("Completed cleanup for pool (env=%s)", environment)
        except Exception as e:
            logger.warning("Failed to cleanup pool in hook: %s", e)

        # Only report status for BrowserStack
        if environment != "browserstack":
            logger.debug("Skipping status reporting for environment: %s", environment)
            continue

        test_passed = not global_failed and not global_skipped
        
        for name, session_manager in session_managers.items():
            if global_skipped:
                report_status = "skipped"
                report_reason = global_reason
            else:
                report_status = "passed" if test_passed else "failed"
                report_reason = global_reason if global_failed else None

            session_id = session_manager.session_id

            if not session_id and hasattr(session_manager, "driver") and session_manager.driver:
                session_id = getattr(session_manager.driver, "session_id", None)
                if session_id:
                    session_manager._session_id = session_id
                    logger.debug(
                        "Captured session_id for %s from driver during reporting",
                        name,
                    )

            if session_id:
                try:
                    session_manager.provider.report_session_status_via_api(
                        session_id, report_status, report_reason
                    )
                    logger.debug(
                        "Reported status '%s' for %s (session: %s)",
                        report_status,
                        name,
                        session_id[:8] if len(session_id) > 8 else session_id,
                    )
                except Exception as e:
                    logger.warning(
                        "Failed to report final status for %s via REST API: %s",
                        name,
                        e,
                    )
            else:
                logger.warning(
                    "Cannot report status for %s: no session_id available. "
                    "Session may remain 'running' on BrowserStack.",
                    name,
                )

    # Get screenshot and page source artifacts
    try:
        if getattr(rep, "failed", False) and not getattr(
            item, "_failure_artifacts_saved", False
        ):
            driver = None
            try:
                if hasattr(item, "instance") and hasattr(item.instance, "driver"):
                    driver = item.instance.driver
            except Exception:
                driver = None

            if driver:
                # Resolve screenshots directory from environment config; fallback to 'screenshots'
                try:
                    config_obj = get_config()
                    screenshots_dir = config_obj.screenshots_dir or "screenshots"
                    logs_dir = config_obj.logs_dir or "logs"
                except Exception:
                    screenshots_dir = "screenshots"
                    logs_dir = "logs"

                test_id = getattr(item, "name", "test") + (
                    f"__{rep.when}" if getattr(rep, "when", None) else ""
                )

                s_path = None
                x_path = None
                try:
                    s_path = save_screenshot(
                        driver, str(screenshots_dir), f"FAILED_{test_id}"
                    )
                except Exception:
                    pass
                try:
                    x_path = save_page_source(
                        driver, str(screenshots_dir), f"FAILED_{test_id}"
                    )
                except Exception:
                    pass

                log = get_logger("conftest")
                if s_path:
                    log.info(f"Saved failure screenshot: {s_path}")
                if x_path:
                    log.info(f"Saved failure page source: {x_path}")

                # Capture Appium server/logcat logs for deeper diagnostics
                log_paths: List[Path] = []
                try:
                    log_types = set(getattr(driver, "log_types", []) or [])
                except Exception:
                    log_types = set()

                desired_types = [
                    log_type
                    for log_type in ("server", "logcat")
                    if log_type in log_types
                ]
                if desired_types:
                    logs_root = Path(logs_dir)
                    logs_root.mkdir(parents=True, exist_ok=True)
                    for log_type in desired_types:
                        try:
                            entries = driver.get_log(log_type) or []
                        except Exception as err:
                            log.warning(
                                f"Failed to fetch '{log_type}' log for {test_id}: {err}"
                            )
                            continue

                        if not entries:
                            continue

                        log_file = logs_root / f"FAILED_{test_id}_{log_type}.log"
                        try:
                            with log_file.open("w", encoding="utf-8") as handle:
                                for entry in entries:
                                    timestamp = (
                                        entry.get("timestamp")
                                        or entry.get("time")
                                        or ""
                                    )
                                    level = entry.get("level") or ""
                                    message = entry.get("message") or ""
                                    handle.write(f"{timestamp}\t{level}\t{message}\n")
                            log.info(f"Saved failure {log_type} log: {log_file}")
                            log_paths.append(log_file)
                        except Exception as err:
                            log.warning(
                                f"Failed to persist {log_type} log for {test_id}: {err}"
                            )

                if log_paths:
                    global _saved_failure_logs
                    _saved_failure_logs.extend(log_paths)

                setattr(item, "_failure_artifacts_saved", True)
    except Exception as e:
        log = get_logger("conftest")
        log.warning(f"Artifact capture failed: {e}")


def pytest_terminal_summary(terminalreporter, exitstatus, config):
    if not _logging_setup:
        return

    logger = _logging_setup["loggers"]["main"]

    passed = len(terminalreporter.stats.get("passed", []))
    failed = len(terminalreporter.stats.get("failed", []))
    skipped = len(terminalreporter.stats.get("skipped", []))
    errors = len(terminalreporter.stats.get("error", []))

    total = passed + failed + skipped + errors

    logger.info("=" * 60)
    logger.info("TEST EXECUTION SUMMARY")
    logger.info("=" * 60)
    logger.info("Total tests: %s", total)
    logger.info("Passed: %s", passed)
    logger.info("Failed: %s", failed)
    logger.info("Skipped: %s", skipped)
    logger.info("Errors: %s", errors)

    if total > 0:
        success_rate = (passed / total) * 100
        logger.info("Success rate: %.1f%%", success_rate)

    logger.info("Reports Generated:")
    if hasattr(config.option, "xmlpath") and config.option.xmlpath:
        xml_file = Path(config.option.xmlpath)
        if xml_file.exists():
            logger.info("  XML report: %s", xml_file)
        else:
            logger.warning("  XML report expected but not found: %s", xml_file)

    if hasattr(config.option, "htmlpath") and config.option.htmlpath:
        html_file = Path(config.option.htmlpath)
        if html_file.exists():
            logger.info("  HTML report: %s", html_file)
        else:
            logger.warning("  HTML report expected but not found: %s", html_file)

    logger.info("=" * 60)

    if failed > 0:
        logger.warning("%s test(s) failed. Check reports for details.", failed)

        failed_tests = terminalreporter.stats.get("failed", [])
        for test_report in failed_tests[:5]:
            test_name = test_report.nodeid.split("::")[-1]
            details = _extract_summary_details(test_report)
            logger.error("  %s: %s", test_name, details["message"])

        if len(failed_tests) > 5:
            logger.error(f"  ... and {len(failed_tests) - 5} more failures")

    if errors > 0:
        logger.error("%s test(s) had errors. Check reports for details.", errors)

        error_tests = terminalreporter.stats.get("error", [])
        for test_report in error_tests[:3]:
            test_name = test_report.nodeid.split("::")[-1]
            details = _extract_summary_details(test_report)
            logger.error("  %s: %s", test_name, details["message"])

        if len(error_tests) > 3:
            logger.error(f"  ... and {len(error_tests) - 3} more errors")

    if passed == total and total > 0:
        logger.info("All tests passed successfully!")

    logger.info("=" * 60)

    if _saved_failure_logs:
        logger.info("Failure log artifacts:")
        for path in _saved_failure_logs:
            logger.info("  %s", path)
