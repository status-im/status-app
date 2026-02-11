#!/usr/bin/env python3

import argparse
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import List

from config import get_config
from core.config_manager import ConfigurationManager

project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))


def run_command(cmd, description):
    print(f"\nRunning {description}")
    print(f"Command: {' '.join(cmd)}")
    print("-" * 60)

    try:
        _ = subprocess.run(cmd, check=True, capture_output=False)
        print(f"{description} completed successfully")
        return True
    except subprocess.CalledProcessError as e:
        print(f"{description} failed with exit code {e.returncode}")
        return False


def _remove_pytest_option(arguments: List[str], option: str) -> List[str]:
    cleaned: List[str] = []
    skip_next = False
    for value in arguments:
        if skip_next:
            skip_next = False
            continue
        if value == option:
            skip_next = True
            continue
        cleaned.append(value)
    return cleaned


def validate_environment():
    print("\nValidating environment configuration")

    try:
        config = get_config(refresh=True)
        print(f"Configuration loaded for provider '{config.provider_name}'")
        print(
            f"Device: {config.device_name} "
            f"({config.platform_name} {config.platform_version})"
        )
        if config.app_reference:
            print(f"App Reference: {config.app_reference}")
        concurrency = config.concurrency
        print(f"Concurrency: up to {concurrency.get('max_sessions', 1)} sessions")
        return True
    except Exception as e:
        print(f"Configuration validation failed: {e}")
        return False


def main():
    manager = ConfigurationManager()
    available_envs = manager.list_available_environments()
    if not available_envs:
        available_envs = ["local"]

    parser = argparse.ArgumentParser(description="Test Runner with XML/HTML Reports")
    parser.add_argument(
        "--category",
        "-c",
        choices=["gate", "smoke", "tablet", "critical", "all"],
        default="gate",
        help="Test category to run (default: gate). Use 'smoke' for full nightly set.",
    )
    parser.add_argument(
        "--parallel",
        "-n",
        type=int,
        default=None,
        help="Number of parallel processes (default: from config)",
    )
    parser.add_argument(
        "--env",
        "-e",
        choices=available_envs,
        default=None,
        help="Environment to run tests in (default: auto-detect)",
    )
    parser.add_argument("--config", "-f", help="Custom configuration file path")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    parser.add_argument(
        "--retry", "-r", action="store_true", help="Enable retry for flaky tests"
    )
    parser.add_argument(
        "--device-id",
        help="Override the device id defined in the environment configuration",
    )
    parser.add_argument(
        "--device-tag",
        action="append",
        dest="device_tags",
        help="Filter available devices by tag (can be specified multiple times)",
    )
    parser.add_argument(
        "--test",
        "-t",
        help="Run specific test (e.g., test_click_create_profile_button)",
    )
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="Only validate configuration, don't run tests",
    )
    parser.add_argument(
        "--no-xml", action="store_true", help="Disable XML report generation"
    )
    parser.add_argument(
        "--no-html", action="store_true", help="Disable HTML report generation"
    )
    parser.add_argument(
        "--reports-dir", help="Custom reports directory (overrides config)"
    )

    args = parser.parse_args()

    if args.env:
        os.environ["TEST_ENVIRONMENT"] = args.env

    if args.device_id:
        os.environ["TEST_DEVICE_ID"] = args.device_id

    if args.device_tags:
        os.environ["TEST_DEVICE_TAGS"] = ",".join(args.device_tags)

    try:
        config = get_config(refresh=True)

        if args.reports_dir:
            config.reports_dir = args.reports_dir

        if args.no_xml:
            config.enable_xml_report = False
        if args.no_html:
            config.enable_html_report = False

        if not validate_environment():
            print("\nEnvironment validation failed!")
            return 1
        if args.validate_only:
            print("\nConfiguration validation completed successfully!")
            return 0

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

        reports_dir = Path(config.reports_dir)
        reports_dir.mkdir(exist_ok=True)

        cmd: List[str] = ["python", "-m", "pytest"]
        if config.pytest_addopts:
            cmd.extend(config.pytest_addopts)
        cmd.extend(["--env", config.environment_name])

        if args.category != "all":
            cmd.extend(["-m", args.category])

        parallel_processes = args.parallel
        if parallel_processes:
            cmd = _remove_pytest_option(cmd, "-n")
            cmd.extend(["-n", str(parallel_processes)])
        else:
            parallel_processes = config.concurrency.get("max_sessions", 1)
            if "-n" not in cmd and parallel_processes > 1:
                cmd.extend(["-n", str(parallel_processes)])

        if args.retry:
            cmd.extend(["--reruns", "2", "--reruns-delay", "1"])

        if args.verbose:
            cmd.append("-v")

        if args.test:
            cmd.extend(["-k", args.test])

        xml_file = None
        if config.enable_xml_report:
            xml_file = reports_dir / f"pytest_results_{timestamp}.xml"
            cmd.extend(["--junitxml", str(xml_file)])

        html_file = None
        if config.enable_html_report:
            html_file = reports_dir / f"pytest_report_{timestamp}.html"
            cmd.extend(["--html", str(html_file), "--self-contained-html"])

        if "test/e2e_appium/tests" in cmd:
            cmd.remove("test/e2e_appium/tests")
        cmd.append("test/e2e_appium/tests")

        print("=" * 60)
        print("E2E TEST RUNNER")
        print("=" * 60)
        print(
            f"Environment: {config.environment_name} (provider {config.provider_name})"
        )
        print(f"Category: {args.category}")
        print(f"Parallel: {parallel_processes} processes")
        print(f"Retry: {'Enabled' if args.retry else 'Disabled'}")
        print(f"Verbose: {'Yes' if args.verbose else 'No'}")
        if args.test:
            print(f"Specific Test: {args.test}")
        print("Reports:")
        if config.enable_xml_report:
            print(f"  XML (JUnit): {xml_file}")
        if config.enable_html_report:
            print(f"  HTML: {html_file}")
        print("=" * 60)

        success = run_command(cmd, f"Running {args.category} tests")
        if success:
            print("\nAll tests completed successfully!")
            print("Generated reports:")
            if config.enable_xml_report and xml_file and xml_file.exists():
                print(f"  XML report: {xml_file}")
            if config.enable_html_report and html_file and html_file.exists():
                print(f"  HTML report: {html_file}")
            return 0
        else:
            print("\nSome tests failed.")
            print("Reports available for analysis:")
            if config.enable_xml_report and xml_file and xml_file.exists():
                print(f"  XML report: {xml_file}")
            if config.enable_html_report and html_file and html_file.exists():
                print(f"  HTML report: {html_file}")
            return 1
    except ValueError as e:
        print(f"\nConfiguration error: {e}")
        return 1
    except Exception as e:
        print(f"\nUnexpected error: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
