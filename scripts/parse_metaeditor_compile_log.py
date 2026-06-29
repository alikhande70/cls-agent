#!/usr/bin/env python3
"""Parse a MetaEditor (MQL5) compile log into a readiness summary.

READ-ONLY helper. This script ONLY reads a compile-log text file and writes
report files. It does NOT control MetaTrader 5 or MetaEditor, send orders,
enable AutoTrade, modify EA parameters, connect to a broker, or store any
credentials. See docs/AGENT_COMPANION_BOUNDARY.md.

Usage:
    python3 scripts/parse_metaeditor_compile_log.py compile_log.txt \
        --out compile_summary.md --json-out compile_summary.json \
        [--commit <hash>] [--timestamp <iso8601>]

Exit codes:
    0  no compile errors found
    1  one or more compile errors found (blocking)
    2  usage / IO error (could not read the log)
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

# MetaEditor diagnostic line, e.g.:
#   CLSAgent_RiskEngine.mqh(123,45) : error 246: some message
#   CLSAgent_RiskEngine.mqh(50,9) : warning 43: some message
# The code number is optional in some MetaEditor builds.
DIAG_RE = re.compile(
    r"^(?P<file>.+?)\((?P<line>\d+)(?:,(?P<col>\d+))?\)\s*:\s*"
    r"(?P<severity>error|warning)\s*(?P<code>\d+)?\s*:\s*(?P<message>.*)$",
    re.IGNORECASE,
)

# Trailing summary line, e.g.:
#   Result: 0 errors, 1 warnings, ...
#   2 error(s), 0 warning(s)
SUMMARY_RE = re.compile(
    r"(?P<errors>\d+)\s*error(?:\(s\))?s?\b.*?(?P<warnings>\d+)\s*warning(?:\(s\))?s?\b",
    re.IGNORECASE,
)


def parse_log(text: str) -> dict:
    errors: list[dict] = []
    warnings: list[dict] = []
    reported = None  # (errors, warnings) from the summary line if present

    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue

        m = DIAG_RE.match(line)
        if m:
            entry = {
                "file": m.group("file").strip(),
                "line": int(m.group("line")),
                "col": int(m.group("col")) if m.group("col") else None,
                "code": m.group("code"),
                "message": m.group("message").strip(),
            }
            if m.group("severity").lower() == "error":
                errors.append(entry)
            else:
                warnings.append(entry)
            continue

        s = SUMMARY_RE.search(line)
        if s and ("error" in line.lower()):
            reported = {
                "errors": int(s.group("errors")),
                "warnings": int(s.group("warnings")),
            }

    files_affected = sorted({e["file"] for e in errors} | {w["file"] for w in warnings})

    return {
        "errors": errors,
        "warnings": warnings,
        "files_affected": files_affected,
        "reported_summary": reported,
    }


def next_actions(total_errors: int, total_warnings: int) -> list[str]:
    if total_errors > 0:
        return [
            "Fix the compile errors listed above (report them before changing "
            "EA trading logic).",
            "Re-compile in MetaEditor and capture a fresh compile_log.txt.",
            "Re-run this parser until 0 errors are reported.",
        ]
    actions = ["Gate 1 (Compile Verification) passes: 0 errors."]
    if total_warnings > 0:
        actions.append(
            "Review the warnings above and document why each is acceptable."
        )
    actions.append(
        "Proceed to Gate 2 (Signal-Only Test): run the Strategy Tester with "
        "Mode=SIGNAL_ONLY, AutoTrade=false."
    )
    return actions


def build_report(parsed: dict, commit: str | None, timestamp: str | None) -> dict:
    total_errors = len(parsed["errors"])
    total_warnings = len(parsed["warnings"])
    blocking = total_errors > 0

    return {
        "gate": "1 - Compile Verification",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "commit": commit,
        "compile_timestamp": timestamp,
        "total_errors": total_errors,
        "total_warnings": total_warnings,
        "reported_summary": parsed["reported_summary"],
        "files_affected": parsed["files_affected"],
        "errors": parsed["errors"],
        "warnings": parsed["warnings"],
        "blocking": blocking,
        "status": "FAIL" if blocking else "PASS",
        "recommended_next_actions": next_actions(total_errors, total_warnings),
    }


def _fmt_diag(d: dict) -> str:
    loc = f"{d['file']}({d['line']}" + (f",{d['col']}" if d["col"] is not None else "") + ")"
    code = f" [{d['code']}]" if d["code"] else ""
    return f"- `{loc}`{code}: {d['message']}"


def to_markdown(report: dict) -> str:
    lines = [
        "# Compile Verification Summary",
        "",
        "_Gate 1 — Compile Verification. Engineering readiness check, not "
        "financial advice._",
        "",
        f"- **Status:** {report['status']}"
        f"{' (blocking)' if report['blocking'] else ''}",
        f"- **Generated:** {report['generated_at']}",
        f"- **Commit:** {report['commit'] or 'n/a'}",
        f"- **Compile timestamp:** {report['compile_timestamp'] or 'n/a'}",
        f"- **Total errors:** {report['total_errors']}",
        f"- **Total warnings:** {report['total_warnings']}",
    ]
    if report["reported_summary"]:
        rs = report["reported_summary"]
        lines.append(
            f"- **Compiler-reported totals:** {rs['errors']} errors, "
            f"{rs['warnings']} warnings"
        )
    lines.append("")

    if report["files_affected"]:
        lines.append("## Files affected")
        lines += [f"- `{f}`" for f in report["files_affected"]]
        lines.append("")

    lines.append("## Errors")
    lines += [_fmt_diag(e) for e in report["errors"]] or ["- none"]
    lines.append("")
    lines.append("## Warnings")
    lines += [_fmt_diag(w) for w in report["warnings"]] or ["- none"]
    lines.append("")
    lines.append("## Recommended next actions")
    lines += [f"- {a}" for a in report["recommended_next_actions"]]
    lines.append("")
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Parse a MetaEditor compile log.")
    ap.add_argument("log", help="Path to the MetaEditor compile log text file.")
    ap.add_argument("--out", help="Path to write the markdown summary.")
    ap.add_argument("--json-out", dest="json_out", help="Path to write the JSON summary.")
    ap.add_argument("--commit", help="Commit hash of the compiled source (optional).")
    ap.add_argument("--timestamp", help="Compile timestamp to record (optional).")
    args = ap.parse_args(argv)

    log_path = Path(args.log)
    try:
        text = log_path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        print(f"error: cannot read log file {log_path}: {exc}", file=sys.stderr)
        return 2

    report = build_report(parse_log(text), args.commit, args.timestamp)
    markdown = to_markdown(report)

    if args.out:
        Path(args.out).write_text(markdown, encoding="utf-8")
    if args.json_out:
        Path(args.json_out).write_text(
            json.dumps(report, indent=2) + "\n", encoding="utf-8"
        )
    if not args.out and not args.json_out:
        print(markdown)

    print(
        f"[compile] status={report['status']} errors={report['total_errors']} "
        f"warnings={report['total_warnings']}",
        file=sys.stderr,
    )
    return 1 if report["blocking"] else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
