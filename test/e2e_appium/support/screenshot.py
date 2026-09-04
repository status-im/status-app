import re
from datetime import datetime
from pathlib import Path
from typing import Optional


def _sanitize(name: str) -> str:
    safe = re.sub(r"[^A-Za-z0-9_.-]+", "_", name.strip())
    return safe[:120] if len(safe) > 120 else safe


def build_screenshot_path(base_dir: str, name: Optional[str] = None) -> Path:
    base = Path(base_dir or "screenshots")
    base.mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    stem = _sanitize(name or "screenshot")
    return base / f"{stem}_{ts}.png"


def save_screenshot(driver, base_dir: str, name: Optional[str] = None) -> Optional[str]:
    try:
        path = build_screenshot_path(base_dir, name)
        # Some drivers return bool, others return path; normalize to path string
        _ = driver.get_screenshot_as_file(str(path))
        return str(path)
    except Exception:
        return None


def build_pagesource_path(base_dir: str, name: Optional[str] = None) -> Path:
    base = Path(base_dir or "screenshots")
    base.mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    stem = _sanitize(name or "page_source")
    return base / f"{stem}_{ts}.xml"


def save_page_source(
    driver, base_dir: str, name: Optional[str] = None
) -> Optional[str]:
    try:
        path = build_pagesource_path(base_dir, name)
        # page_source returns a string containing XML
        xml = driver.page_source
        with open(path, "w", encoding="utf-8") as f:
            f.write(xml if isinstance(xml, str) else str(xml))
        return str(path)
    except Exception:
        return None
