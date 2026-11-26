import os
import xml.etree.ElementTree as ET
from pathlib import Path
summary = Path(os.environ["GITHUB_STEP_SUMMARY"])
path = Path("test/e2e/junit.xml")
if not path.is_file():
    summary.write_text("No junit report.\n")
    raise SystemExit
rows = []
for case in ET.parse(path).getroot().iter("testcase"):
    failed = case.find("failure")
    if failed is None:
        failed = case.find("error")
    if failed is None:
        continue
    name = case.get("classname", "") + "::" + case.get("name", "")
    text = (failed.get("message") or failed.text or "").strip().splitlines()
    line = text[0] if text else ""
    rows.append((name.replace("|", "\\|"), line.replace("|", "\\|")))
if not rows:
    summary.write_text("No failed tests.\n")
    raise SystemExit
lines = ["| Test | Error |", "| --- | --- |"]
lines += [f"| {name} | {line} |" for name, line in rows]
summary.write_text("\n".join(lines) + "\n")
