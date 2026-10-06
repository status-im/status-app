#!/usr/bin/env bash
# Host tests for the Android status-go IPC transport (C++ codec + pure-Java helpers).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${IPC_TEST_OUT:-$(mktemp -d)}"
# Not plain clang++: the mobile Makefile puts the NDK toolchain first on PATH.
CXX_HOST="${CXX_HOST:-/usr/bin/c++}"

for src in "$HERE"/*_test.cpp; do
  bin="$OUT/$(basename "${src%.cpp}")"
  "$CXX_HOST" -std=c++17 -Wall -Wextra -Werror -O1 -fsanitize=address,undefined -I"$HERE/.." "$src" -o "$bin"
  "$bin"
done

# Pure-Java IPC helpers (no Android classes), compiled straight against JUnit 4.
JAVA_ROOT="$HERE/../../android/qt6"
JAVA_SOURCES=(
  "$JAVA_ROOT/src/app/status/mobile/ipc/SignalEnvelope.java"
)
if [[ -z "${JUNIT_JAR:-}" ]]; then
  JUNIT_JAR="$(find "$HOME/.gradle/caches" -name 'junit-4.13.2.jar' 2>/dev/null | head -1)"
  HAMCREST_JAR="$(find "$HOME/.gradle/caches" -name 'hamcrest-core-1.3.jar' 2>/dev/null | head -1)"
fi
if [[ -z "${JUNIT_JAR:-}" || -z "${HAMCREST_JAR:-}" ]]; then
  echo "ipc-host-tests: JUnit 4.13.2 / hamcrest-core 1.3 not found; set JUNIT_JAR and HAMCREST_JAR" >&2
  exit 1
fi
CP="$JUNIT_JAR:$HAMCREST_JAR"
mkdir -p "$OUT/java"
TESTS=()
while IFS= read -r t; do TESTS+=("$t"); done < <(find "$JAVA_ROOT/test" -name '*Test.java')
javac -d "$OUT/java" -cp "$CP" "${JAVA_SOURCES[@]}" "${TESTS[@]}"
CLASSES=()
for t in "${TESTS[@]}"; do
  rel="${t#"$JAVA_ROOT/test/"}"
  rel="${rel%.java}"
  CLASSES+=("${rel//\//.}")
done
java -cp "$OUT/java:$CP" org.junit.runner.JUnitCore "${CLASSES[@]}"
