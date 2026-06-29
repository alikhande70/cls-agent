# Risk Boundary Audit (Gate 4)

This is the workflow for **Gate 4 — Risk Engine Traceability** in
[REAL_ACCOUNT_READINESS_GATE.md](REAL_ACCOUNT_READINESS_GATE.md). It uses
exported logs to demonstrate, after the fact, that the Risk Engine was never
bypassed and that basket limits held.

## What it checks

`scripts/audit_cls_risk_boundary.py` cross-checks the exported CSVs:

1. **Trade traceability (no Risk Engine bypass).** Every row in `trades.csv`
   must correspond to a `journal.csv` row with `riskApproved=true` **and**
   `executed=true` for the same `symbol` + `setup`. A trade with no approved,
   executed journal context is evidence of a bypass and **fails** the gate.
2. **Basket size within cap.** No `baskets.csv` row may have `ordersCount`
   above the configured `--max-orders-per-basket` (default 2; structural
   hardcap is 5, `CLS_MAX_ORDERS_PER_BASKET_HARDCAP`).
3. **No add to losing basket.** For each `symbol`+`direction`, the basket's
   `ordersCount` must never increase on a row marked `isLosing=true`
   (`CLS_NO_ADD_TO_LOSING_BASKET` is a fixed `true` constant in the EA).
4. **(Optional) Strategy layer has no order calls.** With `--source-root`, the
   audit also confirms `MQL5/Include/CLSAgent/Strategy/` contains no
   `OrderSend(` / `CLS_SendMarketOrder(` call (comments and strings stripped).
5. **(Optional) Basket risk ceiling.** With `--max-basket-risk-percent`, it
   flags any `baskets.csv` row whose `riskPercent` exceeds the configured
   total basket risk.

If the required CSVs are missing, the audit returns **INCONCLUSIVE** and lists
what is needed — it never guesses a pass.

## Inputs

- `journal.csv`
- `trades.csv`
- `baskets.csv`
- `performance.csv` (used by the performance review, Gate 7)

## Usage

```bash
python3 scripts/audit_cls_risk_boundary.py path/to/package \
    --max-orders-per-basket 2 \
    --max-basket-risk-percent 0.30 \
    --source-root MQL5 \
    --out risk_boundary_audit.md \
    --json-out risk_boundary_audit.json
```

Use the **same** `--max-orders-per-basket` and `--max-basket-risk-percent`
values the run was configured with (the EA defaults are `2` and `0.30`).

## Results

- **PASS** — every trade traces to an approved/executed journal context, no
  basket exceeded its cap, and no losing basket grew.
- **FAIL** — any untraceable trade, any over-cap basket, any add to a losing
  basket, or an order call found in the Strategy layer. Stop and report.
- **INCONCLUSIVE** — required CSVs missing (listed in the report).

## Notes on matching

Traceability matches on `symbol` + `setup` membership, not on an exact 1:1 row
pairing: `trades.csv` logs the **closing** side of deals (a single opened
position can close in several partial-exit deals), while the approved journal
rows are recorded at **open** time. The audit therefore asks the safety-relevant
question — *does every executed trade belong to a symbol/setup the Risk Engine
approved and executed?* — rather than forcing a count match that partial exits
would legitimately break.

## Safety note

The audit only reads exported CSVs (and optionally source files) and writes
report files. It never runs anything, controls MT5, or touches EA parameters.
