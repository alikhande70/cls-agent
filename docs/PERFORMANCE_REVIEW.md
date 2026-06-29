# Performance Review (Gate 7)

This is the workflow for **Gate 7 — Performance Risk Review** in
[REAL_ACCOUNT_READINESS_GATE.md](REAL_ACCOUNT_READINESS_GATE.md). It is an
**engineering** review of risk-relevant performance characteristics from
exported evidence.

> The verdict produced here is an engineering readiness verdict, **not financial
> advice**. Profitability is never guaranteed.

## What it computes

`scripts/review_cls_performance.py` reads `performance.csv` (and `trades.csv` /
`baskets.csv` if present) and reports:

- overall win/loss, win rate, gross profit/loss, net;
- profit factor (recomputed from gross profit / gross loss; `n/a` when there are
  no losing trades);
- per-setup breakdown (A/B/C/D);
- **low sample size** detection (`--min-sample`, default 30);
- **max drawdown** of the cumulative P/L curve (from `trades.csv` when present);
- **setup concentration** risk (top setup's share of all trades vs
  `--max-concentration`, default 0.80);
- observed **max basket orders / max basket risk %** (from `baskets.csv`).

## Verdict

| Verdict | Meaning |
|---|---|
| `PASS_TO_DEMO` | Adequate sample, profit factor at/above target, no concentration/drawdown flags. |
| `NEEDS_REVIEW` | Usable but flagged (e.g. thin sample, below-target PF, high concentration). |
| `REJECT_FOR_NOW` | Adequate sample but net losing (profit factor < 1.0). |
| `INCONCLUSIVE` | No `performance.csv`, or zero closed trades — nothing to review. |

The thresholds are explicit CLI options so the verdict is transparent and
reproducible.

## Usage

```bash
python3 scripts/review_cls_performance.py path/to/package \
    --min-sample 30 \
    --min-profit-factor 1.2 \
    --max-concentration 0.80 \
    --max-drawdown 0 \
    --out performance_review.md \
    --json-out performance_review.json
```

(`--max-drawdown` is optional; omit it to report drawdown without enforcing a
threshold.)

## How this feeds the gates

- A `PASS_TO_DEMO` verdict is an input to the human decision at the start of
  **Gate 8 — Demo Forward Testing** ([DEMO_READINESS.md](DEMO_READINESS.md)).
- `NEEDS_REVIEW` / `REJECT_FOR_NOW` keep the project in backtest/optimization
  (see [../ROADMAP.md](../ROADMAP.md) v0.5.0).
- The verdict never auto-advances a gate and never enables trading.

## Safety note

The review only reads exported CSVs and writes report files. It never runs
anything, controls MT5, or touches EA parameters.
