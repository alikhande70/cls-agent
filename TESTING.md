# Testing

This document describes how to compile and test CLS Agent before any
demo or live use. Do not skip the `SIGNAL_ONLY` Strategy Tester pass —
it is the cheapest way to catch a problem before it can place an order.

## Compiling in MetaEditor

1. Open MetaTrader 5 → **File → Open Data Folder**.
2. Confirm `MQL5/Experts/CLSAgent/CLSAgent.mq5` and the full
   `MQL5/Include/CLSAgent/` folder are present in your data folder.
3. Open MetaEditor (from MT5: **Tools → MetaQuotes Language Editor**, or
   `F4`).
4. Open `CLSAgent.mq5` and press **F7** (Compile).
5. Check the **Errors** tab. There should be 0 errors. Warnings should be
   reviewed but are not automatically blocking.
6. If you get a missing-include error, confirm the entire
   `MQL5/Include/CLSAgent/` folder (all subfolders: `Core`, `Market`,
   `Strategy`, `Risk`, `Execution`, `Memory`, `Reporting`) was copied, not
   just `CLSAgent.mq5` on its own.

If compilation fails, please file a
[Compile Error Report](.github/ISSUE_TEMPLATE/compile-error-report.md)
with the exact error text and line number.

## Running the Strategy Tester

1. In MetaTrader 5: **View → Strategy Tester** (or `Ctrl+R`).
2. **Expert Advisor:** `CLSAgent`.
3. **Symbol:** `XAUUSD` (or your broker's `XAUUSDm` / `GOLD` suffix).
4. **Timeframe:** `M5` or `M15`.
5. **Model:** "Every tick based on real ticks" (or the most accurate
   model your broker's history supports).
6. In the EA's inputs panel: `Mode = SIGNAL_ONLY`, `AutoTrade = false`.
7. Click **Start** and let the test run to completion.

## Recommended first test

| Setting | Value |
|---|---|
| Symbol | `XAUUSD` or `XAUUSDm` |
| Timeframe | `M5` or `M15` |
| Mode | `SIGNAL_ONLY` |
| AutoTrade | `false` |

Only after this passes cleanly should you re-run with `AutoTrade = true`
in the tester, and only after that should you consider a demo account.
Never enable `AutoTrade` on a real account before completing both steps.

## Required outputs

A completed test run should produce, under `MQL5/Files/CLSAgent/`:

- `logs/journal.csv` — tick-by-tick decision journal.
- `reports/trades.csv` — individual trade records.
- `reports/baskets.csv` — basket-level grouping and outcomes.
- `reports/performance.csv` — per-setup (A/B/C/D/E) performance breakdown.
- `reports/backtest_summary.txt` — human-readable run summary.

Also save the Strategy Tester's own report (**Strategy Tester → Report
tab → right-click → Save as Report**, `.htm`/`.html`).

If you'd like to share results, use the
[Backtest Result](.github/ISSUE_TEMPLATE/backtest-result.md) issue
template and attach these files.

## Mechanizing the checks (read-only helpers)

The `scripts/` folder provides read-only Python helpers that turn the exported
files above into gate reports, so the manual checklist below can be checked
mechanically. They never control MT5, connect to a broker, send orders, enable
AutoTrade, or change EA parameters — they only read evidence and write reports.

```bash
# Gate 1 — parse a MetaEditor compile log
python3 scripts/parse_metaeditor_compile_log.py compile_log.txt \
    --out compile_summary.md --json-out compile_summary.json

# Gate 2 — confirm SIGNAL_ONLY produced no trades
python3 scripts/validate_cls_backtest_package.py path/to/package \
    --mode SIGNAL_ONLY --out validation.md --json-out validation.json

# Gate 4 — risk-boundary traceability (no Risk Engine bypass)
python3 scripts/audit_cls_risk_boundary.py path/to/package \
    --max-orders-per-basket 2 --source-root MQL5 \
    --out risk_boundary_audit.md --json-out risk_boundary_audit.json

# Gate 5 — Strategy/Execution separation in source
python3 scripts/static_safety_scan.py --root MQL5 \
    --out safety_scan.md --json-out safety_scan.json

# Gate 7 — engineering performance/demo-readiness review
python3 scripts/review_cls_performance.py path/to/package \
    --out performance_review.md --json-out performance_review.json
```

See [docs/REAL_ACCOUNT_READINESS_GATE.md](docs/REAL_ACCOUNT_READINESS_GATE.md)
for the gate definitions and [docs/](docs/) for each workflow.

## Pass / fail checklist

A test run **passes** if all of the following are true:

- [ ] EA compiles with 0 errors.
- [ ] No missing-include errors.
- [ ] In `SIGNAL_ONLY` mode, no live orders are sent (check `trades.csv`
      is empty or absent).
- [ ] `journal.csv`, `trades.csv`, `baskets.csv`, `performance.csv`, and
      `backtest_summary.txt` are all generated.
- [ ] The Strategy Tester run completes without crashing or freezing.
- [ ] No uncontrolled basket growth (basket size stays within the
      configured risk limits in every basket logged).
- [ ] No evidence the Risk Engine was bypassed (every trade in
      `trades.csv` corresponds to a Risk Engine approval in
      `journal.csv`).
- [ ] No evidence the Strategy layer sent an order directly — every
      order in `trades.csv` should trace back to the Execution layer
      (`CLS_ExecuteBasketOrder()` / `CLS_SendMarketOrder()`) in the logs.

If any box is unchecked, please file a
[Bug Report](.github/ISSUE_TEMPLATE/bug-report.md) before proceeding to
demo or live testing.
