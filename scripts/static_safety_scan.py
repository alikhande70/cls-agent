#!/usr/bin/env python3
"""Static safety scan of the CLS Agent MQL5 source tree.

READ-ONLY helper. This script ONLY reads source files and writes report files.
It does NOT mutate any file, connect to MetaTrader 5, execute orders, control
AutoTrade, or handle credentials. See docs/AGENT_COMPANION_BOUNDARY.md.

It verifies the Strategy / Risk / Execution boundaries have not been weakened:
  - order-sending calls (OrderSend(, CLS_SendMarketOrder() appear ONLY under
    the Execution layer;
  - the Strategy layer contains no order-sending call;
  - reports discoverable safety constants, AutoTrade/Mode defaults, and any
    TODO/FIXME/STUB markers in the source.

A rule that cannot be proven from the source is reported as INCONCLUSIVE rather
than guessed.

Usage:
    python3 scripts/static_safety_scan.py [--root MQL5] \
        --out safety_scan.md --json-out safety_scan.json

Exit codes: 0 = PASS, 1 = FAIL (a boundary violation), 2 = INCONCLUSIVE /
usage error.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

ORDER_CALL_RE = re.compile(r"\b(?:OrderSend|CLS_SendMarketOrder)\s*\(")
MARKER_RE = re.compile(r"\b(TODO|FIXME|STUB)\b")
EXECUTION_SEGMENT = ("Include", "CLSAgent", "Execution")
STRATEGY_SEGMENT = ("Include", "CLSAgent", "Strategy")

CONST_RE = {
    "CLS_NO_ADD_TO_LOSING_BASKET": re.compile(
        r"#define\s+CLS_NO_ADD_TO_LOSING_BASKET\s+(\S+)"),
    "CLS_LLM_CAN_SEND_ORDERS": re.compile(
        r"#define\s+CLS_LLM_CAN_SEND_ORDERS\s+(\S+)"),
    "CLS_ENTRY_REQUIRES_CLOSED_BAR": re.compile(
        r"#define\s+CLS_ENTRY_REQUIRES_CLOSED_BAR\s+(\S+)"),
    "CLS_MAX_ORDERS_PER_BASKET_HARDCAP": re.compile(
        r"#define\s+CLS_MAX_ORDERS_PER_BASKET_HARDCAP\s+(\S+)"),
}
INPUT_RE = {
    "InpMode": re.compile(r"input\s+\S+\s+InpMode\s*=\s*([^;]+);"),
    "InpAutoTrade": re.compile(r"input\s+\S+\s+InpAutoTrade\s*=\s*([^;]+);"),
}


def strip_comments_and_strings(src: str) -> str:
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.DOTALL)
    src = re.sub(r"//.*", "", src)
    src = re.sub(r'"(?:\\.|[^"\\])*"', '""', src)
    src = re.sub(r"'(?:\\.|[^'\\])*'", "''", src)
    return src


def under_segment(path: Path, segment: tuple[str, ...]) -> bool:
    parts = path.parts
    n = len(segment)
    return any(parts[i:i + n] == segment for i in range(len(parts) - n + 1))


def scan(root: Path) -> dict:
    sources = sorted(list(root.rglob("*.mq5")) + list(root.rglob("*.mqh")))
    failures: list[str] = []
    inconclusive: list[str] = []

    order_calls: list[dict] = []   # all order-send call sites
    markers: list[dict] = []
    constants: dict[str, str | None] = {k: None for k in CONST_RE}
    inputs: dict[str, str | None] = {k: None for k in INPUT_RE}

    if not sources:
        return {
            "result": "INCONCLUSIVE",
            "root": str(root),
            "inconclusive": [f"no .mq5/.mqh source files found under {root}"],
            "failures": [],
            "order_call_sites": [],
            "markers": [],
            "constants": constants,
            "input_defaults": inputs,
            "generated_at": datetime.now(timezone.utc).isoformat(),
        }

    for f in sources:
        raw = f.read_text(encoding="utf-8", errors="replace")
        code = strip_comments_and_strings(raw)
        rel = f.relative_to(root)

        for lineno, line in enumerate(code.splitlines(), start=1):
            if ORDER_CALL_RE.search(line):
                order_calls.append({
                    "file": str(rel),
                    "line": lineno,
                    "in_execution": under_segment(f, EXECUTION_SEGMENT),
                    "in_strategy": under_segment(f, STRATEGY_SEGMENT),
                })

        # markers from the raw text (comments included) — they are notes-to-self
        for lineno, line in enumerate(raw.splitlines(), start=1):
            if MARKER_RE.search(line):
                markers.append({"file": str(rel), "line": lineno,
                                "text": line.strip()[:160]})

        # constants / inputs from raw (they're not in comments)
        for name, rx in CONST_RE.items():
            m = rx.search(raw)
            if m and constants[name] is None:
                constants[name] = m.group(1)
        for name, rx in INPUT_RE.items():
            m = rx.search(raw)
            if m and inputs[name] is None:
                inputs[name] = m.group(1).strip()

    # --- Rule: order calls only under Execution ---------------------------
    outside = [c for c in order_calls if not c["in_execution"]]
    in_strategy = [c for c in order_calls if c["in_strategy"]]

    if in_strategy:
        failures.append(
            f"Strategy layer contains {len(in_strategy)} order-sending call(s): "
            + ", ".join(f"{c['file']}:{c['line']}" for c in in_strategy))
    if outside:
        # (Strategy offenders are a subset; report the rest too.)
        non_strategy_outside = [c for c in outside if not c["in_strategy"]]
        if non_strategy_outside:
            failures.append(
                f"{len(non_strategy_outside)} order-sending call(s) outside the "
                f"Execution layer: "
                + ", ".join(f"{c['file']}:{c['line']}" for c in non_strategy_outside))

    if not order_calls:
        inconclusive.append(
            "no OrderSend()/CLS_SendMarketOrder() call sites found at all — "
            "cannot confirm the Execution layer is the order-send site")

    # --- Rule: safety constants present -----------------------------------
    if constants["CLS_LLM_CAN_SEND_ORDERS"] is None:
        inconclusive.append("CLS_LLM_CAN_SEND_ORDERS not found in source")
    elif constants["CLS_LLM_CAN_SEND_ORDERS"].lower() != "false":
        failures.append(
            f"CLS_LLM_CAN_SEND_ORDERS is "
            f"'{constants['CLS_LLM_CAN_SEND_ORDERS']}', expected false")
    if constants["CLS_NO_ADD_TO_LOSING_BASKET"] is None:
        inconclusive.append("CLS_NO_ADD_TO_LOSING_BASKET not found in source")
    elif constants["CLS_NO_ADD_TO_LOSING_BASKET"].lower() != "true":
        failures.append(
            f"CLS_NO_ADD_TO_LOSING_BASKET is "
            f"'{constants['CLS_NO_ADD_TO_LOSING_BASKET']}', expected true")

    # --- result ----------------------------------------------------------
    if failures:
        result = "FAIL"
    elif inconclusive:
        result = "INCONCLUSIVE"
    else:
        result = "PASS"

    return {
        "result": result,
        "root": str(root),
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "files_scanned": len(sources),
        "failures": failures,
        "inconclusive": inconclusive,
        "order_call_sites": order_calls,
        "order_calls_all_in_execution": all(c["in_execution"] for c in order_calls)
        if order_calls else None,
        "markers": markers,
        "constants": constants,
        "input_defaults": inputs,
    }


def to_markdown(report: dict) -> str:
    lines = [
        "# Static Safety Scan",
        "",
        "_Gate 5 — Strategy / Execution Separation. Engineering readiness "
        "check, not financial advice._",
        "",
        f"- **Result:** {report['result']}",
        f"- **Root:** `{report['root']}`",
        f"- **Files scanned:** {report.get('files_scanned', 0)}",
        f"- **Generated:** {report['generated_at']}",
        "",
        "## Order-send boundary",
        "",
        f"- Order-send call sites found: {len(report['order_call_sites'])}",
        f"- All under Execution layer: {report.get('order_calls_all_in_execution')}",
        "",
    ]
    if report["order_call_sites"]:
        lines += ["| File | Line | In Execution? |", "|---|---|---|"]
        for c in report["order_call_sites"]:
            lines.append(f"| `{c['file']}` | {c['line']} | {c['in_execution']} |")
        lines.append("")

    lines.append("## Safety constants")
    for k, v in report["constants"].items():
        lines.append(f"- `{k}` = {v if v is not None else 'NOT FOUND'}")
    lines.append("")
    lines.append("## Input defaults")
    for k, v in report["input_defaults"].items():
        lines.append(f"- `{k}` = {v if v is not None else 'NOT FOUND'}")
    lines.append("")

    lines.append("## TODO / FIXME / STUB markers")
    if report["markers"]:
        for m in report["markers"]:
            lines.append(f"- `{m['file']}:{m['line']}` — {m['text']}")
    else:
        lines.append("- none")
    lines.append("")

    if report["failures"]:
        lines.append("## Failures")
        lines += [f"- {f}" for f in report["failures"]]
        lines.append("")
    if report["inconclusive"]:
        lines.append("## Inconclusive")
        lines += [f"- {i}" for i in report["inconclusive"]]
        lines.append("")
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Static safety scan of MQL5 source.")
    ap.add_argument("--root", default="MQL5",
                    help="Root of the MQL5 source tree (default: MQL5).")
    ap.add_argument("--out", help="Path to write the markdown report.")
    ap.add_argument("--json-out", dest="json_out", help="Path to write the JSON report.")
    args = ap.parse_args(argv)

    root = Path(args.root)
    if not root.is_dir():
        print(f"error: source root not found: {root}", file=sys.stderr)
        return 2

    report = scan(root)
    markdown = to_markdown(report)

    if args.out:
        Path(args.out).write_text(markdown, encoding="utf-8")
    if args.json_out:
        Path(args.json_out).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if not args.out and not args.json_out:
        print(markdown)

    print(f"[safety-scan] result={report['result']}", file=sys.stderr)
    return {"PASS": 0, "FAIL": 1, "INCONCLUSIVE": 2}[report["result"]]


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
