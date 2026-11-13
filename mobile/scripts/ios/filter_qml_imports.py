#!/usr/bin/env python3
# qmake links every QML plugin qmlimportscanner reports into the static iOS app. This wraps
# the scanner and removes the modules matched by the deny file from its output.
# usage: filter_qml_imports.py <qmlimportscanner> <deny-file> <scanner args...>
import json
import re
import subprocess
import sys
from pathlib import Path

scanner, deny_file = sys.argv[1:3]
deny = []
for line in Path(deny_file).read_text().splitlines():
    line = line.split('#', 1)[0].strip()
    if line:
        deny.append(re.compile(line))

out = subprocess.run([scanner] + sys.argv[3:], capture_output=True, text=True, check=True).stdout
imports = [i for i in json.loads(out) if not any(p.search(i.get('name', '')) for p in deny)]
json.dump(imports, sys.stdout, indent=4)
