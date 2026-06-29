#!/usr/bin/env python3
"""Engineering performance / demo-readiness review of CLS Agent outputs.

READ-ONLY helper. This script ONLY reads exported CSV files and writes report
files. It does NOT run anything, control MetaTrader 5, send orders, enable
AutoTrade, modify EA parameters, or connect to a broker. See
docs/AGENT_COMPANION_BOUNDARY.md.

It parses performance.csv (and trades.csv / baskets.csv if present) and emits a
readiness review with a verdict in:
    PASS_TO_DEMO / NEEDS_REVIEW / REJECT_FOR_NOW / INCONCLUSIVE

This verdict is an ENGINEERING readiness verdict based on exported evidence.
It is NOT financial advice and does not guarantee profitability.

Usage:
    python3 scripts/review_cls_performance.py path/to/package \
        [--min-sample 30] [--min-profit-factor 1.2] [--max-concentration 0.80] \
        [--max-drawdown 0] \
        --out performance_review.md --json-out performance_review.json

Exit codes: 0 = PASS_TO_DEMO, 1 = REJECT_FOR_NOW, 2 = NEEDS_REVIEW /
INCONCLUSIVE / usage error.
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
from datetime import datetime, timezone
from pathlib import Path


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


def to_float(value: str, default: float = 0.0) -> float:
    try:
        return float(value)
    except (ValueError, TypeError):
        return default


def to_int(value: str, default: int = 0) -> int:
    try:
        return int(float(value))
    except (ValueError, TypeError):
        return default


def profit_factor(gross_profit: float, gross_loss: float) -> float | None:
    if gross_loss <= 0.0:
        return None  # undefined (no losses) -> reported as n/a
    return gross_profit / gross_loss


def max_drawdown(profits: list[float]) -> float:
    """Max peak-to-trough drawdown of the cumulative P/L curve (absolute)."""
    peak = 0.0
    equity = 0.0
    worst = 0.0
    for p in profits:
        equity += p
        peak = max(peak, equity)
        worst = max(worst, peak - equity)
    return worst


def review(package: Path, min_sample: int, min_pf: float,
           max_conc: float, max_dd: float | None) -> dict:
    flags: list[str] = []
    notes: list[str] = []

    perf_p = find_file(package, "performance.csv")
    if perf_p is None:
        return {
            "gate": "7 - Performance Risk Review",
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "package": str(package),
            "verdict": "INCONCLUSIVE",
            "disclaimer": "Engineering readiness verdict, not financial advice.",
            "flags": [],
            "notes": [],
            "missing_evidence": ["performance.csv"],
            "metrics": {},
            "per_setup": [],
        }

    rows = read_dicts(perf_p)
    by_label = {r.get("setup", ""): r for r in rows}
    all_row = by_label.get("ALL")
    if all_row is None and rows:
        # fall back to the first row if the ALL label is absent
        all_row = rows[0]

    total_trades = to_int(all_row.get("trades", "0")) if all_row else 0
    gross_profit = to_float(all_row.get("grossProfit", "0")) if all_row else 0.0
    gross_loss = to_float(all_row.get("grossLoss", "0")) if all_row else 0.0
    wins = to_int(all_row.get("wins", "0")) if all_row else 0
    losses = to_int(all_row.get("losses", "0")) if all_row else 0
    win_rate = (100.0 * wins / total_trades) if total_trades else 0.0
    pf = profit_factor(gross_profit, gross_loss)
    net = gross_profit - gross_loss

    per_setup = []
    setup_trade_counts = {}
    setup_profit = {}
    for r in rows:
        label = r.get("setup", "")
        if label in ("", "ALL"):
            continue
        t = to_int(r.get("trades", "0"))
        gp = to_float(r.get("grossProfit", "0"))
        gl = to_float(r.get("grossLoss", "0"))
        per_setup.append({
            "setup": label,
            "trades": t,
            "wins": to_int(r.get("wins", "0")),
            "losses": to_int(r.get("losses", "0")),
            "profitFactor": profit_factor(gp, gl),
            "net": gp - gl,
        })
        setup_trade_counts[label] = t
        setup_profit[label] = gp

    # --- drawdown from trades.csv if present ------------------------------
    trades_p = find_file(package, "trades.csv")
    drawdown = None
    if trades_p is not None:
        trades = read_dicts(trades_p)
        profits = [to_float(t.get("profit", "0")) for t in trades]
        if profits:
            drawdown = max_drawdown(profits)
    else:
        notes.append("trades.csv absent — drawdown not computed.")

    # --- uncontrolled basket risk from baskets.csv if present -------------
    baskets_p = find_file(package, "baskets.csv")
    max_basket_orders = None
    max_basket_risk = None
    if baskets_p is not None:
        baskets = read_dicts(baskets_p)
        if baskets:
            max_basket_orders = max(to_int(b.get("ordersCount", "0")) for b in baskets)
            max_basket_risk = max(to_float(b.get("riskPercent", "0")) for b in baskets)
    else:
        notes.append("baskets.csv absent — basket-risk concentration not computed.")

    # --- flags ------------------------------------------------------------
    low_sample = total_trades < min_sample
    if low_sample:
        flags.append(
            f"Low sample size: {total_trades} trades (< {min_sample}); results "
            f"are not statistically meaningful yet.")

    if pf is None:
        notes.append("Profit factor undefined (no losing trades in sample).")
    elif pf < 1.0:
        flags.append(f"Profit factor {pf:.2f} < 1.0 (net losing on this sample).")
    elif pf < min_pf:
        flags.append(f"Profit factor {pf:.2f} below target {min_pf:.2f}.")

    # setup concentration (by trade count and by gross profit)
    concentration = None
    if total_trades > 0 and setup_trade_counts:
        top_label = max(setup_trade_counts, key=setup_trade_counts.get)
        concentration = setup_trade_counts[top_label] / total_trades
        if concentration > max_conc:
            flags.append(
                f"Setup concentration: {top_label} is "
                f"{concentration*100:.0f}% of all trades (> {max_conc*100:.0f}%).")

    if max_dd is not None and drawdown is not None and drawdown > max_dd:
        flags.append(
            f"Max drawdown {drawdown:.2f} exceeds threshold {max_dd:.2f} "
            f"(deposit currency).")

    # --- verdict ----------------------------------------------------------
    if total_trades == 0:
        verdict = "INCONCLUSIVE"
        notes.append("No closed trades recorded — nothing to review yet.")
    elif pf is not None and pf < 1.0 and not low_sample:
        verdict = "REJECT_FOR_NOW"
    elif low_sample:
        verdict = "NEEDS_REVIEW"
    elif flags:
        verdict = "NEEDS_REVIEW"
    else:
        verdict = "PASS_TO_DEMO"

    return {
        "gate": "7 - Performance Risk Review",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "package": str(package),
        "verdict": verdict,
        "disclaimer": "Engineering readiness verdict, not financial advice. "
                      "Profitability is not guaranteed.",
        "flags": flags,
        "notes": notes,
        "missing_evidence": [],
        "metrics": {
            "total_trades": total_trades,
            "wins": wins,
            "losses": losses,
            "win_rate_pct": round(win_rate, 1),
            "gross_profit": gross_profit,
            "gross_loss": gross_loss,
            "net": net,
            "profit_factor": pf,
            "max_drawdown": drawdown,
            "top_setup_concentration": concentration,
            "max_basket_orders": max_basket_orders,
            "max_basket_risk_percent": max_basket_risk,
        },
        "per_setup": per_setup,
        "thresholds": {
            "min_sample": min_sample,
            "min_profit_factor": min_pf,
            "max_concentration": max_conc,
            "max_drawdown": max_dd,
        },
    }


def to_markdown(report: dict) -> str:
    m = report["metrics"]
    lines = [
        "# Performance / Demo-Readiness Review",
        "",
        f"> **{report['disclaimer']}**",
        "",
        f"- **Verdict:** {report['verdict']}",
        f"- **Package:** `{report['package']}`",
        f"- **Generated:** {report['generated_at']}",
        "",
    ]
    if report["missing_evidence"]:
        lines.append("## Missing evidence")
        lines += [f"- {x}" for x in report["missing_evidence"]]
        lines.append("")
        return "\n".join(lines)

    pf = m.get("profit_factor")
    dd = m.get("max_drawdown")
    conc = m.get("top_setup_concentration")
    lines += [
        "## Overall metrics",
        "",
        f"- Trades: {m['total_trades']} (W {m['wins']} / L {m['losses']}, "
        f"win rate {m['win_rate_pct']}%)",
        f"- Gross profit / loss: {m['gross_profit']:.2f} / {m['gross_loss']:.2f}"
        f" (net {m['net']:.2f})",
        f"- Profit factor: {('%.2f' % pf) if pf is not None else 'n/a'}",
        f"- Max drawdown: {('%.2f' % dd) if dd is not None else 'n/a'}",
        f"- Top-setup concentration: {('%.0f%%' % (conc*100)) if conc is not None else 'n/a'}",
        f"- Max basket orders: {m['max_basket_orders'] if m['max_basket_orders'] is not None else 'n/a'}",
        f"- Max basket risk %: {m['max_basket_risk_percent'] if m['max_basket_risk_percent'] is not None else 'n/a'}",
        "",
    ]
    if report["per_setup"]:
        lines += ["## Per-setup", "", "| Setup | Trades | W | L | PF | Net |",
                  "|---|---|---|---|---|---|"]
        for s in report["per_setup"]:
            spf = ("%.2f" % s["profitFactor"]) if s["profitFactor"] is not None else "n/a"
            lines.append(f"| {s['setup']} | {s['trades']} | {s['wins']} | "
                         f"{s['losses']} | {spf} | {s['net']:.2f} |")
        lines.append("")
    lines.append("## Flags")
    lines += [f"- {f}" for f in report["flags"]] or ["- none"]
    lines.append("")
    if report["notes"]:
        lines.append("## Notes")
        lines += [f"- {n}" for n in report["notes"]]
        lines.append("")
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Review CLS Agent performance evidence.")
    ap.add_argument("package", help="Path to the exported package directory.")
    ap.add_argument("--min-sample", type=int, default=30)
    ap.add_argument("--min-profit-factor", type=float, default=1.2)
    ap.add_argument("--max-concentration", type=float, default=0.80)
    ap.add_argument("--max-drawdown", type=float, default=None,
                    help="Optional max drawdown threshold (deposit currency).")
    ap.add_argument("--out", help="Path to write the markdown report.")
    ap.add_argument("--json-out", dest="json_out", help="Path to write the JSON report.")
    args = ap.parse_args(argv)

    package = Path(args.package)
    if not package.is_dir():
        print(f"error: package directory not found: {package}", file=sys.stderr)
        return 2

    report = review(package, args.min_sample, args.min_profit_factor,
                    args.max_concentration, args.max_drawdown)
    markdown = to_markdown(report)

    if args.out:
        Path(args.out).write_text(markdown, encoding="utf-8")
    if args.json_out:
        Path(args.json_out).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if not args.out and not args.json_out:
        print(markdown)

    print(f"[performance] verdict={report['verdict']}", file=sys.stderr)
    return {"PASS_TO_DEMO": 0, "REJECT_FOR_NOW": 1,
            "NEEDS_REVIEW": 2, "INCONCLUSIVE": 2}[report["verdict"]]


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
