#!/usr/bin/env python3
"""Audit CLS Agent risk-boundary evidence from exported logs.

READ-ONLY helper. This script ONLY reads exported CSV files (and, optionally,
the MQL5 source tree) and writes report files. It does NOT run anything,
control MetaTrader 5, send orders, enable AutoTrade, modify EA parameters, or
connect to a broker. See docs/AGENT_COMPANION_BOUNDARY.md.

Checks (from exported evidence):
  1. Every executed trade traces to an approved journal context
     (a journal.csv row with riskApproved=true and executed=true for the same
     symbol+setup) -- i.e. no Risk Engine bypass.
  2. No basket in baskets.csv exceeds the configured max orders per basket.
  3. No losing basket grew in order count (no-add-to-losing-basket rule).
  4. (optional) The Strategy source layer contains no order-sending call.

Insufficient evidence yields INCONCLUSIVE, never a guessed pass.

Usage:
    python3 scripts/audit_cls_risk_boundary.py path/to/package \
        --max-orders-per-basket 2 \
        [--max-basket-risk-percent 0.30] [--source-root MQL5] \
        --out risk_boundary_audit.md --json-out risk_boundary_audit.json

Exit codes: 0 = PASS, 1 = FAIL, 2 = INCONCLUSIVE or usage/IO error.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

HARDCAP_ORDERS_PER_BASKET = 5  # CLS_MAX_ORDERS_PER_BASKET_HARDCAP
ORDER_CALL_RE = re.compile(r"\b(OrderSend|CLS_SendMarketOrder)\s*\(")


def find_file(package: Path, name: str) -> Path | None:
    direct = package / name
    if direct.is_file():
        return direct
    matches = sorted(package.rglob(name))
    return matches[0] if matches else None


def read_dicts(path: Path) -> list[dict]:
    with path.open(newline="", encoding="utf-8", errors="replace") as fh:
        return [
            {k.strip(): (v.strip() if v is not None else "") for k, v in row.items()}
            for row in csv.DictReader(fh)
        ]


def truthy(value: str) -> bool:
    return value.strip().lower() == "true"


def strip_comments(src: str) -> str:
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.DOTALL)
    src = re.sub(r"//.*", "", src)
    src = re.sub(r'"(?:\\.|[^"\\])*"', '""', src)
    return src


def audit(package: Path, max_orders: int, max_risk_pct: float | None,
          source_root: Path | None) -> dict:
    checks: list[dict] = []
    failures: list[str] = []
    missing: list[str] = []

    def add(name: str, ok: bool | None, detail: str) -> None:
        checks.append({"check": name, "ok": ok, "detail": detail})

    journal_p = find_file(package, "journal.csv")
    trades_p = find_file(package, "trades.csv")
    baskets_p = find_file(package, "baskets.csv")

    # --- Check 1: trade -> approved journal traceability ------------------
    if journal_p is None or trades_p is None:
        add("Trade traceability", None,
            "needs both journal.csv and trades.csv")
        if journal_p is None:
            missing.append("journal.csv")
        if trades_p is None:
            missing.append("trades.csv")
    else:
        journal = read_dicts(journal_p)
        trades = read_dicts(trades_p)
        approved_keys = {
            (r.get("symbol", ""), r.get("setup", ""))
            for r in journal
            if truthy(r.get("riskApproved", "")) and truthy(r.get("executed", ""))
        }
        untraceable = [
            t for t in trades
            if (t.get("symbol", ""), t.get("setup", "")) not in approved_keys
        ]
        if not trades:
            add("Trade traceability", True, "no trades recorded (nothing to trace)")
        elif untraceable:
            ex = ", ".join(
                f"{t.get('symbol','?')}/{t.get('setup','?')}" for t in untraceable[:5]
            )
            add("Trade traceability", False,
                f"{len(untraceable)} trade(s) with no approved+executed journal "
                f"context (e.g. {ex})")
            failures.append(
                f"{len(untraceable)} trade(s) cannot be traced to a Risk-Engine-"
                f"approved journal row")
        else:
            add("Trade traceability", True,
                f"all {len(trades)} trade(s) trace to an approved journal context")

    # --- Checks 2 & 3: basket size cap + no-add-to-losing -----------------
    if baskets_p is None:
        add("Basket size within cap", None, "needs baskets.csv")
        add("No add to losing basket", None, "needs baskets.csv")
        missing.append("baskets.csv")
    else:
        baskets = read_dicts(baskets_p)
        # Cap check
        over_cap = []
        for r in baskets:
            try:
                n = int(r.get("ordersCount", "0"))
            except ValueError:
                continue
            if n > max_orders:
                over_cap.append(r)
        if over_cap:
            add("Basket size within cap", False,
                f"{len(over_cap)} basket row(s) exceed max {max_orders} orders")
            failures.append(
                f"{len(over_cap)} basket row(s) exceed configured max "
                f"{max_orders} orders per basket")
        else:
            add("Basket size within cap", True,
                f"no basket exceeds {max_orders} orders "
                f"(hardcap {HARDCAP_ORDERS_PER_BASKET})")

        # No-add-to-losing: per (symbol, direction), count must not increase
        # while isLosing=true. baskets.csv is append-only in time order.
        prev: dict[tuple[str, str], int] = {}
        violations = []
        for r in baskets:
            key = (r.get("symbol", ""), r.get("direction", ""))
            try:
                n = int(r.get("ordersCount", "0"))
            except ValueError:
                continue
            was = prev.get(key)
            if was is not None and n > was and truthy(r.get("isLosing", "")):
                violations.append(r)
            prev[key] = n
        if violations:
            add("No add to losing basket", False,
                f"{len(violations)} growth event(s) on a losing basket")
            failures.append(
                f"{len(violations)} basket(s) grew in order count while marked "
                f"isLosing=true")
        else:
            add("No add to losing basket", True,
                "no losing basket grew in order count")

        # Optional risk-percent ceiling
        if max_risk_pct is not None:
            over_risk = []
            for r in baskets:
                try:
                    rp = float(r.get("riskPercent", "0"))
                except ValueError:
                    continue
                if rp > max_risk_pct + 1e-9:
                    over_risk.append(r)
            if over_risk:
                add("Basket risk percent within cap", False,
                    f"{len(over_risk)} basket row(s) exceed {max_risk_pct}%")
                failures.append(
                    f"{len(over_risk)} basket row(s) exceed configured basket "
                    f"risk {max_risk_pct}%")
            else:
                add("Basket risk percent within cap", True,
                    f"no basket exceeds {max_risk_pct}%")

    # --- Check 4: Strategy source has no order calls (optional) -----------
    if source_root is not None:
        strat_dir = source_root / "Include" / "CLSAgent" / "Strategy"
        if not strat_dir.is_dir():
            # tolerate being pointed straight at the Strategy dir
            alt = source_root / "Strategy"
            strat_dir = alt if alt.is_dir() else strat_dir
        if not strat_dir.is_dir():
            add("Strategy layer has no order calls", None,
                f"Strategy source dir not found under {source_root}")
            missing.append("Strategy source directory")
        else:
            offenders = []
            for f in sorted(strat_dir.rglob("*.mqh")):
                if ORDER_CALL_RE.search(strip_comments(f.read_text(
                        encoding="utf-8", errors="replace"))):
                    offenders.append(f.name)
            if offenders:
                add("Strategy layer has no order calls", False,
                    f"order call found in: {', '.join(offenders)}")
                failures.append(
                    f"Strategy layer contains order-sending call(s): "
                    f"{', '.join(offenders)}")
            else:
                add("Strategy layer has no order calls", True,
                    "no OrderSend/CLS_SendMarketOrder in Strategy/")

    if failures:
        result = "FAIL"
    elif missing:
        result = "INCONCLUSIVE"
    else:
        result = "PASS"

    return {
        "gate": "4 - Risk Engine Traceability",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "package": str(package),
        "max_orders_per_basket": max_orders,
        "max_basket_risk_percent": max_risk_pct,
        "result": result,
        "checks": checks,
        "failures": failures,
        "missing_evidence": missing,
    }


def to_markdown(report: dict) -> str:
    lines = [
        "# Risk Boundary Audit",
        "",
        "_Gate 4 — Risk Engine Traceability. Engineering readiness check, not "
        "financial advice._",
        "",
        f"- **Result:** {report['result']}",
        f"- **Package:** `{report['package']}`",
        f"- **Max orders per basket:** {report['max_orders_per_basket']} "
        f"(hardcap {HARDCAP_ORDERS_PER_BASKET})",
        f"- **Max basket risk %:** {report['max_basket_risk_percent'] if report['max_basket_risk_percent'] is not None else 'not checked'}",
        f"- **Generated:** {report['generated_at']}",
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
            "_Missing evidence yields INCONCLUSIVE — provide the inputs above "
            "and re-run rather than treating absence as a pass._")
        lines.append("")
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Audit CLS Agent risk boundary.")
    ap.add_argument("package", help="Path to the exported package directory.")
    ap.add_argument("--max-orders-per-basket", type=int, default=2,
                    help="Configured InpMaxOrdersPerBasket (default 2).")
    ap.add_argument("--max-basket-risk-percent", type=float, default=None,
                    help="Optional InpBasketRiskPercent ceiling to enforce.")
    ap.add_argument("--source-root", default=None,
                    help="Optional path to the MQL5/ tree for the Strategy-layer "
                         "source check.")
    ap.add_argument("--out", help="Path to write the markdown report.")
    ap.add_argument("--json-out", dest="json_out", help="Path to write the JSON report.")
    args = ap.parse_args(argv)

    package = Path(args.package)
    if not package.is_dir():
        print(f"error: package directory not found: {package}", file=sys.stderr)
        return 2
    if args.max_orders_per_basket < 1 or args.max_orders_per_basket > HARDCAP_ORDERS_PER_BASKET:
        print(f"error: --max-orders-per-basket must be 1..{HARDCAP_ORDERS_PER_BASKET}",
              file=sys.stderr)
        return 2
    source_root = Path(args.source_root) if args.source_root else None

    report = audit(package, args.max_orders_per_basket,
                   args.max_basket_risk_percent, source_root)
    markdown = to_markdown(report)

    if args.out:
        Path(args.out).write_text(markdown, encoding="utf-8")
    if args.json_out:
        Path(args.json_out).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if not args.out and not args.json_out:
        print(markdown)

    print(f"[risk-audit] result={report['result']}", file=sys.stderr)
    return {"PASS": 0, "FAIL": 1, "INCONCLUSIVE": 2}[report["result"]]


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
