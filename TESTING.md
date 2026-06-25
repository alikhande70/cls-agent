# Testing

This document describes how to compile and test CLS Agent before any
demo or live use. Do not skip the `SIGNAL_ONLY` Strategy Tester pass —
it is the cheapest way to catch a problem before it can place an order.

**No real-money account should be used before, in order: (1) a clean
MetaEditor compile, (2) a clean `SIGNAL_ONLY` Strategy Tester run, (3) a
clean `AutoTrade = true` Strategy Tester run, and (4) demo-account
forward testing over a meaningful sample of trades.** This document is
not a claim that the EA is live-ready — see [DISCLAIMER.md](DISCLAIMER.md).

## Compile / backtest readiness checklist

- [ ] MetaEditor compile: **pending**
- [ ] Strategy Tester, `Mode = SIGNAL_ONLY`: **pending**
- [ ] Strategy Tester, `AutoTrade = true`: **pending**
- [ ] Demo forward test: **pending**
- [ ] Live trading: **not recommended** (no compile/backtest/demo
      evidence has been published yet for this codebase)

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
- `reports/performance.csv` — per-setup (A/B/C/D) performance breakdown.
- `reports/backtest_summary.txt` — human-readable run summary.

Also save the Strategy Tester's own report (**Strategy Tester → Report
tab → right-click → Save as Report**, `.htm`/`.html`).

If you'd like to share results, use the
[Backtest Result](.github/ISSUE_TEMPLATE/backtest-result.md) issue
template and attach these files.

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
