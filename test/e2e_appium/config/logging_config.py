import os
import sys
import json
import logging
import logging.handlers
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, Optional
from dataclasses import dataclass


@dataclass
class LoggingConfig:
    # Logging levels and output
    console_level: str = "INFO"
    file_level: str = "DEBUG"
    log_format: str = "structured"  # 'simple', 'detailed', 'structured'

    # File logging settings
    logs_dir: str = "logs"
    max_file_size: int = 10 * 1024 * 1024  # 10MB
    backup_count: int = 5

    # Performance tracking
    enable_performance_logging: bool = True
    performance_threshold_ms: int = 1000  # Log slow operations

    # Features
    enable_console_colors: bool = True
    enable_json_logging: bool = True
    log_sensitive_data: bool = False


class ColoredFormatter(logging.Formatter):
    """Colored console formatter for better readability."""

    COLORS = {
        "DEBUG": "\033[36m",  # Cyan
        "INFO": "\033[32m",  # Green
        "WARNING": "\033[33m",  # Yellow
        "ERROR": "\033[31m",  # Red
        "CRITICAL": "\033[35m",  # Magenta
        "RESET": "\033[0m",  # Reset
    }

    def format(self, record):
        if hasattr(record, "no_color") or not sys.stdout.isatty():
            return super().format(record)

        level_color = self.COLORS.get(record.levelname, self.COLORS["RESET"])
        record.levelname = f"{level_color}{record.levelname}{self.COLORS['RESET']}"
        return super().format(record)


class StructuredFormatter(logging.Formatter):
    """JSON structured formatter for machine-readable logs."""

    def format(self, record):
        log_entry = {
            "timestamp": datetime.fromtimestamp(record.created).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno,
        }

        # Add extra fields if present
        if hasattr(record, "test_name"):
            log_entry["test_name"] = record.test_name
        if hasattr(record, "session_id"):
            log_entry["session_id"] = record.session_id
        if hasattr(record, "duration_ms"):
            log_entry["duration_ms"] = record.duration_ms
        if hasattr(record, "element_locator"):
            log_entry["element_locator"] = record.element_locator

        return json.dumps(log_entry)


class PerformanceTracker:
    """Track and log performance metrics with historical analysis."""

    def __init__(
        self,
        logger: logging.Logger,
        threshold_ms: int = 1000,
        enable_analytics: bool = False,
    ):
        self.logger = logger
        self.threshold_ms = threshold_ms
        self.start_time = None
        self.operation_name = None

        # Check environment variable override
        env_analytics = os.getenv("E2E_ENABLE_PERFORMANCE_ANALYTICS", "").lower()
        if env_analytics in ("true", "1", "yes", "on"):
            enable_analytics = True
        elif env_analytics in ("false", "0", "no", "off"):
            enable_analytics = False

        self.enable_analytics = enable_analytics

        # Initialize analytics if enabled
        if self.enable_analytics:
            try:
                from .performance_analytics import (
                    PerformanceAnalytics,
                    PerformanceMetric,
                )

                self.analytics = PerformanceAnalytics()
                self.PerformanceMetric = PerformanceMetric
            except ImportError:
                self.logger.warning(
                    "Performance analytics unavailable - running without historical analysis"
                )
                self.enable_analytics = False

    def start(self, operation_name: str, **context):
        """Start timing an operation."""
        self.operation_name = operation_name
        self.start_time = datetime.now()
        self.context = context

        self.logger.debug(f"🚀 Started: {operation_name}", extra=context)

    def end(self, success: bool = True, **result_context):
        """End timing and log results with historical analysis."""
        if not self.start_time:
            return

        end_time = datetime.now()
        duration = end_time - self.start_time
        duration_ms = int(duration.total_seconds() * 1000)

        log_data = {
            "duration_ms": duration_ms,
            "operation": self.operation_name,
            "success": success,
            **self.context,
            **result_context,
        }

        # Historical analysis
        if self.enable_analytics and hasattr(self, "analytics"):
            try:
                # Get comprehensive test context
                test_name = result_context.get(
                    "test_name", self.context.get("test_name", "unknown_test")
                )
                session_id = result_context.get(
                    "session_id", self.context.get("session_id", "unknown_session")
                )

                # Try to get comprehensive device info from config
                device_info = "unknown"
                device_type = "unknown"
                platform = "unknown"
                platform_version = "unknown"

                try:
                    from .settings import get_config

                    config = get_config()
                    device_info = config.device_name
                    platform = config.platform_name.lower()
                    platform_version = config.platform_version

                    # Determine device type based on device name
                    device_name_lower = config.device_name.lower()
                    if (
                        "tablet" in device_name_lower
                        or "ipad" in device_name_lower
                        or "tab s8" in device_name_lower
                        or "galaxy tab" in device_name_lower
                    ):
                        device_type = "tablet"
                    elif (
                        "desktop" in device_name_lower or "chrome" in device_name_lower
                    ):
                        device_type = "desktop"
                    else:
                        device_type = "phone"

                except Exception:
                    device_info = self.context.get("device", "unknown")

                metric = self.PerformanceMetric(
                    test_name=test_name,
                    operation_name=self.operation_name,
                    duration_ms=duration_ms,
                    success=success,
                    timestamp=end_time,
                    session_id=session_id,
                    environment=self.context.get("environment", "lambdatest"),
                    device=device_info,
                    device_type=device_type,
                    platform=platform,
                    platform_version=platform_version,
                )

                # This will log enhanced analytics
                analysis = self.analytics.record_performance(metric)

                # Add analytics to log data
                log_data.update(
                    {
                        "historical_analysis": {
                            "average_ms": analysis.average_duration_ms,
                            "delta_ms": analysis.performance_delta_ms,
                            "delta_percent": analysis.performance_delta_percent,
                            "percentile": analysis.percentile_ranking,
                            "trend": analysis.performance_trend,
                            "total_runs": analysis.total_runs,
                        }
                    }
                )

            except Exception as e:
                self.logger.debug(f"Analytics error: {e}")

        # Log level based on performance and success
        if not success:
            level = logging.ERROR
            emoji = "❌"
        elif duration_ms > self.threshold_ms:
            level = logging.WARNING
            emoji = "⚠️"
        else:
            level = logging.INFO
            emoji = "✅"

        self.logger.log(
            level, f"{emoji} {self.operation_name}: {duration_ms}ms", extra=log_data
        )


def setup_logging(config: Optional[LoggingConfig] = None) -> Dict[str, Any]:
    """
    Set up logging configuration.

    Returns:
        Dict with logger instances and configuration info.
    """
    if config is None:
        config = LoggingConfig()

    # Create logs directory (create parents for nested per-run paths)
    logs_dir = Path(config.logs_dir)
    logs_dir.mkdir(parents=True, exist_ok=True)

    # Clear any existing handlers
    root_logger = logging.getLogger()
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)

    # Console handler with colors
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(getattr(logging, config.console_level.upper()))

    if config.enable_console_colors:
        console_format = "%(asctime)s | %(levelname)-8s | %(name)-20s | %(message)s"
        console_handler.setFormatter(ColoredFormatter(console_format))
    else:
        console_format = "%(asctime)s | %(levelname)-8s | %(name)-20s | %(message)s"
        console_handler.setFormatter(logging.Formatter(console_format))

    # File handler with rotation
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = logs_dir / f"test_run_{timestamp}.log"

    file_handler = logging.handlers.RotatingFileHandler(
        log_file, maxBytes=config.max_file_size, backupCount=config.backup_count
    )
    file_handler.setLevel(getattr(logging, config.file_level.upper()))

    if config.log_format == "structured":
        file_handler.setFormatter(StructuredFormatter())
    else:
        file_format = "%(asctime)s | %(levelname)-8s | %(name)-25s | %(funcName)-15s:%(lineno)-3d | %(message)s"
        file_handler.setFormatter(logging.Formatter(file_format))

    # JSON handler for structured logging
    json_handler = None
    if config.enable_json_logging:
        json_file = logs_dir / f"structured_{timestamp}.json"
        json_handler = logging.FileHandler(json_file)
        json_handler.setLevel(logging.DEBUG)
        json_handler.setFormatter(StructuredFormatter())

    # Configure root logger
    root_logger.setLevel(logging.DEBUG)
    root_logger.addHandler(console_handler)
    root_logger.addHandler(file_handler)
    if json_handler:
        root_logger.addHandler(json_handler)

    # Create specialized loggers
    loggers = {
        "main": logging.getLogger("e2e_appium"),
        "config": logging.getLogger("e2e_appium.config"),
        "tests": logging.getLogger("e2e_appium.tests"),
        "pages": logging.getLogger("e2e_appium.pages"),
        "performance": logging.getLogger("e2e_appium.performance"),
        "session": logging.getLogger("e2e_appium.session"),
    }

    # Log startup information
    main_logger = loggers["main"]
    main_logger.info("=" * 80)
    main_logger.info("🚀 E2E Test Framework Starting")
    main_logger.info("=" * 80)
    main_logger.info(f"📁 Logs directory: {logs_dir.absolute()}")
    main_logger.info(f"📄 Main log file: {log_file.name}")
    if json_handler:
        main_logger.info(f"📊 JSON log file: {json_file.name}")
    main_logger.info(f"🎚️  Console level: {config.console_level}")
    main_logger.info(f"🎚️  File level: {config.file_level}")
    main_logger.info("=" * 80)

    return {
        "loggers": loggers,
        "config": config,
        "log_file": str(log_file),
        "json_file": str(json_file) if json_handler else None,
        "performance_tracker": lambda: PerformanceTracker(loggers["performance"]),
    }


def get_logger(name: str) -> logging.Logger:
    """Get a logger with the specified name."""
    return logging.getLogger(f"e2e_appium.{name}")


def log_test_start(test_name: str, **context):
    """Log test start with context."""
    logger = get_logger("tests")
    logger.info(
        f"🧪 Starting test: {test_name}", extra={"test_name": test_name, **context}
    )


def log_test_end(test_name: str, success: bool, duration_ms: int, **context):
    """Log test completion with results."""
    logger = get_logger("tests")
    emoji = "✅" if success else "❌"
    status = "PASSED" if success else "FAILED"

    logger.info(
        f"{emoji} Test {status}: {test_name} ({duration_ms}ms)",
        extra={
            "test_name": test_name,
            "success": success,
            "duration_ms": duration_ms,
            **context,
        },
    )


def log_element_action(
    action: str, locator: str, success: bool = True, duration_ms: int = 0, **context
):
    """Log element interaction with performance data."""
    logger = get_logger("pages")
    emoji = "✅" if success else "❌"

    logger.info(
        f"{emoji} {action}: {locator} ({duration_ms}ms)",
        extra={
            "action": action,
            "element_locator": locator,
            "success": success,
            "duration_ms": duration_ms,
            **context,
        },
    )


def log_session_info(session_id: str, action: str, **context):
    """Log session management information."""
    logger = get_logger("session")
    logger.info(
        f"🔄 Session {action}: {session_id}",
        extra={"session_id": session_id, **context},
    )
