# Signal-Only Test (Gate 2)

This is the workflow for **Gate 2 — Signal-Only Test** in
[REAL_ACCOUNT_READINESS_GATE.md](REAL_ACCOUNT_READINESS_GATE.md). It is the
cheapest way to review the EA's decisions with **zero order risk**.

## The invariant

With the EA defaults — `Mode = SIGNAL_ONLY` and `AutoTrade = false` — the EA
runs its full pipeline and writes a decision journal, but **never sends an
order**. The order send is double-gated in code: `CLS_ExecuteBasketOrder()` only
proceeds when `g_State.tradingAllowedByMode` is true, which requires
`Mode == CLS_MODE_AUTO_TRADE` **and** `AutoTrade == true`. SIGNAL_ONLY fails
that gate, so no `OrderSend()` is ever reached.

The Gate 2 test confirms this invariant from exported evidence: `journal.csv`
is produced and populated, while `trades.csv` is empty or absent.

## Steps

1. In MetaTrader 5: **View → Strategy Tester** (`Ctrl+R`).
2. **Expert Advisor:** `CLSAgent`.
3. **Symbol:** `XAUUSD` (or your broker's `XAUUSDm` / `GOLD`), **Timeframe:**
   `M5` or `M15`.
4. **Model:** "Every tick based on real ticks" (or the most accurate your
   broker history supports).
5. In the EA inputs, leave `Mode = SIGNAL_ONLY` and `AutoTrade = false`.
6. Run to completion.
7. Collect the outputs described in [BACKTEST_OUTPUTS.md](BACKTEST_OUTPUTS.md)
   into a package directory.

## Validate

```bash
python3 scripts/validate_cls_backtest_package.py path/to/package \
    --mode SIGNAL_ONLY \
    --out validation.md --json-out validation.json
```

- **PASS** — `journal.csv` populated; `trades.csv` empty or absent; required
  files and columns present.
- **FAIL** — any trade recorded in SIGNAL_ONLY mode, or a missing/short column.
- **INCONCLUSIVE** — required evidence missing (the report lists what's needed).

## Acceptance / fail

- **Pass (blocking gate):** the run completes, the journal is populated, and no
  trades were produced.
- **Fail:** any order was sent while configured signal-only — stop and report
  it before proceeding.

A clean SIGNAL_ONLY pass is the prerequisite for enabling `AutoTrade = true` in
the tester (Gate 3).
