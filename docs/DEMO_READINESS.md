# Demo Readiness (Gate 8)

This is the workflow for **Gate 8 — Demo Forward Testing** in
[REAL_ACCOUNT_READINESS_GATE.md](REAL_ACCOUNT_READINESS_GATE.md). It is the
bridge between Strategy Tester validation and any live consideration: the EA
runs on a **demo account** against live data, under real spread, slippage, and
broker execution behavior.

> Nothing here authorizes live trading. Demo readiness is an engineering
> milestone, not financial advice.

## Entry criteria (must hold before starting demo)

- **Gate 1** Compile Verification — PASS.
- **Gate 2** Signal-Only Test — PASS.
- **Gate 3** Strategy Tester Validation — PASS on the primary symbol.
- **Gate 4** Risk Engine Traceability — PASS on the backtest package.
- **Gate 5** Strategy / Execution Separation — PASS (static).
- **Gate 7** Performance Review — a human has reviewed the verdict and chosen to
  proceed.

## Running the demo forward test

1. Use a **demo** account (never a live account at this stage).
2. Attach `CLSAgent` to the primary symbol/timeframe.
3. Set `Mode = AUTO_TRADE` and `AutoTrade = true` **manually, on the demo
   account**. No tool, agent, or Companion may set these — see
   [AGENT_COMPANION_BOUNDARY.md](AGENT_COMPANION_BOUNDARY.md).
4. Keep risk inputs conservative (defaults: `InpBasketRiskPercent = 0.30`,
   `InpMaxOrdersPerBasket = 2`, `InpMaxDailyLossPercent = 1.00`,
   `InpSuperBurst = false`).
5. Let it run over a **meaningful sample** of trades.
6. Periodically collect the exported logs into a package directory.

## Reviewing demo evidence

Run the same read-only tooling against the demo package:

```bash
# Risk boundary must still hold on live-data demo evidence (Gate 4)
python3 scripts/audit_cls_risk_boundary.py path/to/demo_package \
    --max-orders-per-basket 2 --source-root MQL5 \
    --out demo_risk_audit.md --json-out demo_risk_audit.json

# Performance / readiness review (Gate 7) on demo evidence
python3 scripts/review_cls_performance.py path/to/demo_package \
    --out demo_performance.md --json-out demo_performance.json
```

## What to check beyond the numbers

- **Spread / slippage** vs. backtest assumptions.
- **Broker execution behavior:** requotes, partial fills, freeze level,
  filling-mode fallbacks (FOK → IOC → RETURN).
- **Account type:** hedging vs netting (basket logic assumes hedging; the EA
  warns at init otherwise).
- **Stability:** no crashes, no runaway logging, no stuck baskets.

## Acceptance / fail

- **Pass (blocking gate):** demo forward run over a meaningful sample; demo
  evidence passes Gates 4 and 7; broker behavior reviewed and acceptable.
- **Fail:** risk-traceability failure on demo data, or unacceptable divergence
  from backtest expectations. Return to optimization
  (see [../ROADMAP.md](../ROADMAP.md) v0.5.0).

## Next

Only after a successful demo do **Gate 9 — Live Risk Caps** and **Gate 10 —
Human Live Approval** apply. Live activation is always a manual human action.
