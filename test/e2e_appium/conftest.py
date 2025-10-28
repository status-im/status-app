import os
import pytest
from datetime import datetime
from pathlib import Path
from typing import List

from .config import get_config, setup_logging, log_test_start, log_test_end
from .config.logging_config import get_logger, LoggingConfig
from .utils.cloud_reporter import CloudResultReporter
from .utils.screenshot import save_screenshot, save_page_source


# Expose fixture modules without star imports
pytest_plugins = [
    "fixtures.onboarding_fixture",
]


_logging_setup = None
_saved_failure_logs: List[Path] = []


def pytest_configure(config):
    global _logging_setup

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


@pytest.hookimpl(tryfirst=True, hookwrapper=True)
def pytest_runtest_makereport(item, call):
    outcome = yield
    rep = outcome.get_result()

    setattr(item, "rep_" + rep.when, rep)

    # Report setup/call/teardown so setup failures are reflected in the cloud dashboard
    if rep.when in ("setup", "call", "teardown"):
        try:
            CloudResultReporter.report_test_result(item, rep)
        except Exception as e:
            logger = get_logger("session")
            logger.error(f"Failed to report test result to cloud provider: {e}")

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
            if hasattr(test_report, "longrepr") and test_report.longrepr:
                error_msg = (
                    str(test_report.longrepr).split("\n")[-2]
                    if test_report.longrepr
                    else "Unknown error"
                )
                logger.error("  %s: %s", test_name, error_msg)

        if len(failed_tests) > 5:
            logger.error(f"  ... and {len(failed_tests) - 5} more failures")

    if errors > 0:
        logger.error("%s test(s) had errors. Check reports for details.", errors)

        error_tests = terminalreporter.stats.get("error", [])
        for test_report in error_tests[:3]:
            test_name = test_report.nodeid.split("::")[-1]
            if hasattr(test_report, "longrepr") and test_report.longrepr:
                error_msg = (
                    str(test_report.longrepr).split("\n")[-2]
                    if test_report.longrepr
                    else "Unknown error"
                )
                logger.error("  %s: %s", test_name, error_msg)

        if len(error_tests) > 3:
            logger.error(f"  ... and {len(error_tests) - 3} more errors")

    if passed == total and total > 0:
        logger.info("All tests passed successfully!")

    logger.info("=" * 60)

    if _saved_failure_logs:
        logger.info("Failure log artifacts:")
        for path in _saved_failure_logs:
            logger.info("  %s", path)
