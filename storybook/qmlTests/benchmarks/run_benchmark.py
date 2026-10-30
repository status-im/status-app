#!/usr/bin/env python3
"""Runs storybook benchmarks (bench_*.qml) and compares their results.

A benchmark file holds a TestCase named "Bench" with one test function per
variant (test_<variant>), each running a BenchmarkRunner and printing its
result as a "BENCH-RESULT <json>" line. Every run is its own QmlTests process
in a real window - GPU memory deltas are only exact for the first thing a
process builds - with the GPU stats enabled (QML_XHR_ALLOW_FILE_READ=1).

  run_benchmark.py run bench_Foo.qml --variant a --variant b \\
      --scales 1 2 --runs 3 --label before --out before.json
  run_benchmark.py table before.json after.json

A run whose result is marked invalid (too few frames: screen blanked or
locked, compositor stalled) or missing is retried, up to --retries times.

The table gives the median of the runs and, when they differ, the range.
"""

import argparse
import json
import os
import statistics
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_QMLTESTS = os.path.join(SCRIPT_DIR, "..", "..", "build", "test", "bin", "QmlTests")


def run_once(qmltests, bench, variant, scale, extra_env, timeout):
    env = dict(os.environ)
    env["QML_XHR_ALLOW_FILE_READ"] = "1"
    env["QT_SCALE_FACTOR"] = str(scale)
    env.update(extra_env)
    # -maxwarnings 0: past the default 2000 warnings QtTest drops all
    # output, the result line included
    cmd = [qmltests, "-maxwarnings", "0", "-input", bench, f"Bench::test_{variant}"]
    try:
        out = subprocess.run(cmd, env=env, capture_output=True, text=True,
                             timeout=timeout).stdout
    except subprocess.TimeoutExpired:
        return None, "timeout"
    for line in out.splitlines():
        marker = line.find("BENCH-RESULT ")
        if marker >= 0:
            return json.loads(line[marker + len("BENCH-RESULT "):]), None
    failures = [l for l in out.splitlines() if l.startswith("FAIL")]
    return None, "; ".join(failures) or "no result"


def cmd_run(args):
    extra_env = dict(kv.split("=", 1) for kv in args.env)
    entries = []
    for variant in args.variant:
        for scale in args.scales:
            runs = []
            for i in range(args.runs):
                for attempt in range(1, args.retries + 1):
                    result, error = run_once(args.qmltests, args.bench, variant, scale,
                                             extra_env, args.timeout)
                    ok = result is not None and result.get("valid")
                    status = "ok" if ok else (error or "invalid: " + json.dumps(
                        {"ready": f"{result['build']['ready']}/{result['count']}",
                         **{k: v.get("fps") for k, v in result["scenarios"].items()}}))
                    print(f"{args.label} {variant} {scale:g}x run {i + 1} attempt {attempt}: {status}",
                          file=sys.stderr, flush=True)
                    # the benchmark does not load: no retry can help
                    if error and "::compile()" in error:
                        sys.exit(1)
                    if ok:
                        runs.append(result)
                        break
            entries.append({"variant": variant, "scale": scale, "runs": runs})
    data = {"label": args.label, "bench": os.path.basename(args.bench), "entries": entries}
    text = json.dumps(data, indent=1)
    if args.out:
        with open(args.out, "w") as f:
            f.write(text)
    else:
        print(text)


METRICS = [
    ("GPU memory", lambda r: r["build"]["gpuMiB"], "MiB", 1),
    ("RSS", lambda r: r["build"]["rssMiB"], "MiB", 1),
    ("build, sync", lambda r: r["build"]["syncMsPerItem"], "ms/item", 3),
    ("build, until ready", lambda r: r["build"]["readyMs"], "ms", 0),
]
SCENARIO_METRICS = [
    ("GPU/frame", "gpuMsPerFrame", "ms", 2),
    ("CPU/frame", "cpuMsPerFrame", "ms", 2),
    ("frame rate", "fps", "fps", 0),
]


def summary(values, digits, unit):
    values = [v for v in values if v is not None and v == v]  # drop NaN
    if not values:
        return "n/a"
    med = statistics.median(values)
    lo, hi = min(values), max(values)
    fmt = f"{{:.{digits}f}}"
    if fmt.format(lo) == fmt.format(hi):
        return f"{fmt.format(med)} {unit}"
    return f"{fmt.format(med)} {unit} ({fmt.format(lo)}..{fmt.format(hi)})"


def cmd_table(args):
    columns = []  # (title, {(scale): runs})
    for path in args.results:
        with open(path) as f:
            data = json.load(f)
        variants = sorted({e["variant"] for e in data["entries"]},
                          key=[e["variant"] for e in data["entries"]].index)
        for variant in variants:
            title = data["label"] if len(variants) == 1 else f"{data['label']} {variant}"
            by_scale = {e["scale"]: e["runs"] for e in data["entries"] if e["variant"] == variant}
            columns.append((title, by_scale))

    scales = sorted({s for _, by_scale in columns for s in by_scale})
    scenario_names = []
    for _, by_scale in columns:
        for runs in by_scale.values():
            for r in runs:
                for name in r["scenarios"]:
                    if name not in scenario_names:
                        scenario_names.append(name)

    rows = []
    for scale in scales:
        for label, get, unit, digits in METRICS:
            rows.append((f"{label}, {scale:g}x",
                         [summary([get(r) for r in by_scale.get(scale, [])], digits, unit)
                          for _, by_scale in columns]))
        for name in scenario_names:
            for label, key, unit, digits in SCENARIO_METRICS:
                rows.append((f"{name}, {label}, {scale:g}x",
                             [summary([r["scenarios"][name][key] for r in by_scale.get(scale, [])
                                       if name in r["scenarios"]], digits, unit)
                              for _, by_scale in columns]))

    width0 = max(len(r[0]) for r in rows)
    widths = [max(len(c[0]), *(len(r[1][i]) for r in rows)) for i, c in enumerate(columns)]
    print("  " + " " * width0 + "  " + "  ".join(c[0].ljust(w) for c, w in zip(columns, widths)))
    for name, cells in rows:
        print("  " + name.ljust(width0) + "  " + "  ".join(c.ljust(w) for c, w in zip(cells, widths)))

    counts = {len(runs) for _, by_scale in columns for runs in by_scale.values()}
    print(f"\n  runs per cell: {', '.join(map(str, sorted(counts)))}", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    run = sub.add_parser("run")
    run.add_argument("bench")
    run.add_argument("--variant", action="append", required=True)
    run.add_argument("--scales", nargs="+", type=float, default=[1, 2])
    run.add_argument("--runs", type=int, default=3)
    run.add_argument("--retries", type=int, default=3)
    run.add_argument("--label", default="result")
    run.add_argument("--out")
    run.add_argument("--env", action="append", default=[], help="NAME=VALUE for the runs")
    run.add_argument("--timeout", type=int, default=600)
    run.add_argument("--qmltests", default=os.environ.get("QMLTESTS", DEFAULT_QMLTESTS))
    run.set_defaults(func=cmd_run)

    table = sub.add_parser("table")
    table.add_argument("results", nargs="+")
    table.set_defaults(func=cmd_table)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
