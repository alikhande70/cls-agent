#!/usr/bin/env python3
"""Validate an exported CLS Agent backtest/test output package.

READ-ONLY helper. This script ONLY validates exported files. It does NOT run
backtests, control MetaTrader 5 / MetaEditor, send orders, enable AutoTrade,
modify EA parameters, or connect to a broker. See
docs/AGENT_COMPANION_BOUNDARY.md.

It checks an exported package directory for the files CLS Agent produces, that
required CSV columns exist, that files are non-empty where expected, and (in
SIGNAL_ONLY mode) that no trades were recorded.

Usage:
    python3 scripts/validate_cls_backtest_package.py path/to/package \
        --mode SIGNAL_ONLY \
        --out validation.md --json-out validation.json

Result values: PASS / FAIL / INCONCLUSIVE.
Exit codes: 0 = PASS, 1 = FAIL, 2 = INCONCLUSIVE or usage/IO error.
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

# Verified headers from the EA's Memory/Reporting modules.
EXPECTED_COLUMNS = {
    "journal.csv": [
        "time", "symbol", "setup", "direction", "entry", "sl", "tp", "score",
        "scoreStatus", "riskApproved", "lots", "rejectReason", "executed", "ticket",
    ],
    "trades.csv": [
        "time", "symbol", "setup", "magic", "positionId",
        "closeVolume", "closePrice", "profit",
    ],
    "baskets.csv": [
        "time", "symbol", "direction", "ordersCount", "totalLots",
        "averageEntry", "isLosing", "riskPercent",
    ],
    "performance.csv": [
        "setup", "trades", "wins", "losses", "winRatePct",
        "profitFactor", "grossProfit", "grossLoss",
    ],
}

# Files the EA produces. journal.csv is required in every mode; trades.csv is
# required-present only when execution was enabled (handled per-mode below).
CORE_CSVS = ["journal.csv", "baskets.csv", "performance.csv"]
SUMMARY_FILE = "backtest_summary.txt"


def find_file(package: Path, name: str) -> Path | None:
    """Find a file by basename anywhere under the package dir.

    Exports may keep the CLSAgent/logs + CLSAgent/reports layout or be
    flattened; search recursively and return the first match.
    """
    direct = package / name
    if direct.is_file():
        return direct
    matches = sorted(package.rglob(name))
    return matches[0] if matches else None


def read_csv_rows(path: Path) -> tuple[list[str], list[list[str]]]:
    with path.open(newline="", encoding="utf-8", errors="replace") as fh:
        rows = [r for r in csv.reader(fh) if r and any(c.strip() for c in r)]
    if not rows:
        return [], []
    return [c.strip() for c in rows[0]], rows[1:]


def check_columns(name: str, header: list[str]) -> list[str]:
    """Return a list of missing required columns for a CSV."""
    expected = EXPECTED_COLUMNS.get(name, [])
    present = set(header)
    return [c for c in expected if c not in present]


def find_htm_report(package: Path) -> Path | None:
    for pattern in ("*.htm", "*.html"):
        matches = sorted(package.rglob(pattern))
        if matches:
            return matches[0]
    return None


def validate(package: Path, mode: str) -> dict:
    checks: list[dict] = []
    missing_evidence: list[str] = []
    failures: list[str] = []

    def add(name: str, ok: bool | None, detail: str) -> None:
        checks.append({"check": name, "ok": ok, "detail": detail})

    # --- core CSV files present + columns ---------------------------------
    for name in CORE_CSVS:
        path = find_file(package, name)
        if path is None:
            add(f"{name} present", None, "file not found")
            missing_evidence.append(name)
            continue
        header, data = read_csv_rows(path)
        if not header:
            add(f"{name} present", False, "file is empty (no header)")
            failures.append(f"{name} is empty")
            continue
        missing_cols = check_columns(name, header)
        if missing_cols:
            add(f"{name} columns", False, f"missing columns: {', '.join(missing_cols)}")
            failures.append(f"{name} missing columns: {', '.join(missing_cols)}")
        else:
            add(f"{name} columns", True, f"{len(header)} columns, {len(data)} data rows")
        # journal.csv should have decision rows
        if name == "journal.csv" and not data:
            add("journal.csv non-empty", False, "no decision rows recorded")
            failures.append("journal.csv has no decision rows")

    # --- backtest_summary.txt --------------------------------------------
    summary = find_file(package, SUMMARY_FILE)
    if summary is None:
        add(f"{SUMMARY_FILE} present", None, "file not found")
        missing_evidence.append(SUMMARY_FILE)
    elif summary.stat().st_size == 0:
        add(f"{SUMMARY_FILE} present", False, "file is empty")
        failures.append(f"{SUMMARY_FILE} is empty")
    else:
        add(f"{SUMMARY_FILE} present", True, f"{summary.stat().st_size} bytes")

    # --- performance.csv parseable ---------------------------------------
    perf = find_file(package, "performance.csv")
    if perf is not None:
        try:
            phdr, prows = read_csv_rows(perf)
            add("performance.csv parseable", True, f"{len(prows)} rows parsed")
        except (OSError, csv.Error) as exc:
            add("performance.csv parseable", False, f"parse error: {exc}")
            failures.append("performance.csv is not parseable")

    # --- Strategy Tester .htm/.html report -------------------------------
    htm = find_htm_report(package)
    if htm is None:
        add("Strategy Tester report (.htm/.html)", None, "not found (recommended)")
        missing_evidence.append("Strategy Tester .htm/.html report")
    else:
        add("Strategy Tester report (.htm/.html)", True, htm.name)

    # --- trades.csv: mode-dependent --------------------------------------
    trades = find_file(package, "trades.csv")
    trades_rows: list[list[str]] = []
    trades_data_count = 0
    if trades is not None:
        thdr, trades_rows = read_csv_rows(trades)
        trades_data_count = len(trades_rows)
        missing_cols = check_columns("trades.csv", thdr) if thdr else ["(no header)"]
        if thdr and missing_cols:
            add("trades.csv columns", False, f"missing columns: {', '.join(missing_cols)}")
            failures.append(f"trades.csv missing columns: {', '.join(missing_cols)}")

    if mode == "SIGNAL_ONLY":
        # Invariant: signal-only must not produce trades.
        if trades is None:
            add("SIGNAL_ONLY: no trades", True, "trades.csv absent (expected)")
        elif trades_data_count == 0:
            add("SIGNAL_ONLY: no trades", True, "trades.csv present but empty (expected)")
        else:
            add("SIGNAL_ONLY: no trades", False,
                f"trades.csv has {trades_data_count} trade rows in SIGNAL_ONLY mode")
            failures.append(
                f"SIGNAL_ONLY violated: {trades_data_count} trades recorded")
    else:  # AUTO_TRADE
        if trades is None:
            add("trades.csv present", None, "file not found")
            missing_evidence.append("trades.csv")
        else:
            add("trades.csv present", True, f"{trades_data_count} trade rows")

    # --- verdict ----------------------------------------------------------
    if failures:
        result = "FAIL"
    elif missing_evidence:
        result = "INCONCLUSIVE"
    else:
        result = "PASS"

    return {
        "gate": "2/3/6 - Strategy Tester / Signal-Only / Backtest output validation",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "package": str(package),
        "mode": mode,
        "result": result,
        "checks": checks,
        "failures": failures,
        "missing_evidence": missing_evidence,
        "trades_recorded": trades_data_count,
    }


def to_markdown(report: dict) -> str:
    lines = [
        "# Backtest Package Validation",
        "",
        "_Engineering readiness check, not financial advice._",
        "",
        f"- **Result:** {report['result']}",
        f"- **Mode:** {report['mode']}",
        f"- **Package:** `{report['package']}`",
        f"- **Generated:** {report['generated_at']}",
        f"- **Trades recorded:** {report['trades_recorded']}",
        "",
        "## Checks",
        "",
        "| Check | Status | Detail |",
        "|---|---|---|",
    ]
    for c in report["checks"]:
        status = "PASS" if c["ok"] is True else ("FAIL" if c["ok"] is False else "MISSING")
        lines.append(f"| {c['check']} | {status} | {c['detail']} |")
    lines.append("")
    if report["failures"]:
        lines.append("## Failures")
        lines += [f"- {f}" for f in report["failures"]]
        lines.append("")
    if report["missing_evidence"]:
        lines.append("## Missing evidence")
        lines += [f"- {m}" for m in report["missing_evidence"]]
        lines.append("")
        lines.append(
            "_Missing evidence yields an INCONCLUSIVE result — provide the "
            "files above and re-run rather than treating absence as a pass._"
        )
        lines.append("")
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Validate a CLS Agent backtest package.")
    ap.add_argument("package", help="Path to the exported package directory.")
    ap.add_argument("--mode", choices=["SIGNAL_ONLY", "AUTO_TRADE"],
                    default="SIGNAL_ONLY", help="Expected run mode.")
    ap.add_argument("--out", help="Path to write the markdown report.")
    ap.add_argument("--json-out", dest="json_out", help="Path to write the JSON report.")
    args = ap.parse_args(argv)

    package = Path(args.package)
    if not package.is_dir():
        print(f"error: package directory not found: {package}", file=sys.stderr)
        return 2

    report = validate(package, args.mode)
    markdown = to_markdown(report)

    if args.out:
        Path(args.out).write_text(markdown, encoding="utf-8")
    if args.json_out:
        Path(args.json_out).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if not args.out and not args.json_out:
        print(markdown)

    print(f"[validate] result={report['result']} mode={report['mode']}", file=sys.stderr)
    return {"PASS": 0, "FAIL": 1, "INCONCLUSIVE": 2}[report["result"]]


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
