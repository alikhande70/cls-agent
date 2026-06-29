# Strategy Tester Validation (Gates 3 & 6)

This workflow validates a full Strategy Tester run for **Gate 3 — Strategy
Tester Validation** and, repeated across symbols/timeframes, **Gate 6 —
Multi-Symbol / Multi-Timeframe Backtest** in
[REAL_ACCOUNT_READINESS_GATE.md](REAL_ACCOUNT_READINESS_GATE.md).

Do Gate 2 ([SIGNAL_ONLY_TEST.md](SIGNAL_ONLY_TEST.md)) first.

## Step 1 — Run the tester with execution enabled

1. **View → Strategy Tester** (`Ctrl+R`).
2. **Expert Advisor:** `CLSAgent`.
3. **Symbol / Timeframe:** start with `XAUUSD` on `M5` or `M15`.
4. **Model:** "Every tick based on real ticks" where possible.
5. In the EA inputs, set `Mode = AUTO_TRADE` and `AutoTrade = true` **inside the
   tester only**. (This is a tester run, not a live or demo account.)
6. Run to completion.

> Note on account type: basket logic needs several simultaneous positions per
> symbol/direction, which only a **hedging** account preserves as distinct
> positions. A netting account merges them. The EA warns about this at init;
> prefer a hedging-mode test configuration for representative basket behavior.

## Step 2 — Collect outputs

Gather into one package directory (see
[BACKTEST_OUTPUTS.md](BACKTEST_OUTPUTS.md)):

- `journal.csv`, `trades.csv`, `baskets.csv`, `performance.csv`,
  `backtest_summary.txt`
- the Strategy Tester `.htm` / `.html` report

## Step 3 — Validate

```bash
python3 scripts/validate_cls_backtest_package.py path/to/package \
    --mode AUTO_TRADE \
    --out validation.md --json-out validation.json
```

The validator checks required files exist, required columns are present, files
are non-empty where expected, `performance.csv` parses, and the Strategy Tester
report is present.

- **PASS** — all required files/columns present and consistent.
- **FAIL** — a missing column, an empty required file, or an unparseable
  `performance.csv`.
- **INCONCLUSIVE** — required files missing (listed in the report).

## Step 4 — Follow-on gates

A validated `AUTO_TRADE` package feeds:

- **Gate 4 — Risk Engine Traceability:**
  [RISK_BOUNDARY_AUDIT.md](RISK_BOUNDARY_AUDIT.md)
- **Gate 7 — Performance Risk Review:**
  [PERFORMANCE_REVIEW.md](PERFORMANCE_REVIEW.md)

## Gate 6 — multi-symbol / multi-timeframe

Repeat Steps 1–3 for each primary symbol (`XAUUSD`, `EURUSD`, `GBPUSD`,
`USDJPY`) and at least two timeframes (e.g. M5, M15). Each package must pass
Gate 3 validation. Keep each package's `validation.*` outputs as the Gate 6
evidence set.

## Safety note

`validate_cls_backtest_package.py` only reads exported files and writes report
files. It never runs the tester, controls MT5, or touches EA parameters.
