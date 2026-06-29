# EA Architecture Review

This document is a **read-only architecture review** of CLS Agent as it exists
today. It records the module roles, the data flow through the pipeline, and the
two structural safety rules that are enforced in code. It does **not** propose
or make any change to trading logic — it is the baseline reference the rest of
the readiness layer is built against.

Reviewed source: `MQL5/Experts/CLSAgent/CLSAgent.mq5` and
`MQL5/Include/CLSAgent/**`. Version constant: `CLS_AGENT_VERSION = "2.4.0"`
(`MQL5/Include/CLSAgent/Core/CLSAgent_Constants.mqh`).

## Module roles

| Module | Path | Responsibility |
|---|---|---|
| Core | `MQL5/Include/CLSAgent/Core/` | Shared types, constants, inputs, runtime state, lifecycle wiring, logging/utility helpers |
| Market | `MQL5/Include/CLSAgent/Market/` | Symbol profile, sessions, ATR indicator/regime, rolling spread buffer, level cache |
| Strategy | `MQL5/Include/CLSAgent/Strategy/` | Setup detection (A–D), Score Engine, Decision Engine — produces a scored signal, never an order |
| Risk | `MQL5/Include/CLSAgent/Risk/` | Daily-loss limits, news guard, basket risk, lot sizing; the single approval authority |
| Execution | `MQL5/Include/CLSAgent/Execution/` | Broker mechanics: order sending, retries, slippage/partial-fill, position management — only after Risk approval |
| Memory | `MQL5/Include/CLSAgent/Memory/` | Append-only journal, trade log, basket log, running performance stats |
| Reporting | `MQL5/Include/CLSAgent/Reporting/` | On-chart debug panel, `performance.csv` export, Strategy Tester `backtest_summary.txt` |

## Pipeline data flow

`OnTick()` in `CLSAgent.mq5` is a **thin orchestrator** — it holds no trading
logic of its own. Once per *closed* bar (Rule #6, `CLS_State_IsNewBar`) it calls
the pipeline stages in a fixed order:

```
Market Data
  → BuildSetupContext()            (Core/Market: session, ATR regime, spread, levels)
  → CLS_DetectSetups()             (Strategy: Setup A/B/C/D detection)
  → CLS_DecideSignal()             (Strategy: Score Engine + Decision Engine score gate)
  → CLS_EvaluateRisk()             (Risk: hard gates + daily loss + news + basket risk + lot size)
  → CLS_ExecuteBasketOrder()       (Execution: final Mode/AutoTrade veto, then order send)
  → CLS_ManageOpenPositions()      (Execution: breakeven / partial exit / trailing)
  → CLS_Journal_LogSignal()        (Memory: one journal.csv row per considered signal)
  → CLS_BasketLog_Update()         (Memory: baskets.csv row when basket composition changes)
  → CLS_DebugPanel_Update()        (Reporting: on-chart visibility only)
```

Closed positions are detected separately, off the bar cadence, via
`OnTradeTransaction()` → `CLS_TradeLog_OnDealAdded()` (writes `trades.csv` and
feeds `PerformanceStats`), because the broker can fill an SL/TP directly without
the EA ever requesting it. End-of-run reports
(`CLS_Report_ExportPerformanceCSV()`, `CLS_BacktestReport_Generate()`) run from
`OnDeinit()` / `OnTester()`.

## The two enforced structural rules

These are not conventions — they are enforced by the shape of the code:

1. **The Strategy layer never sends orders.** Setup detectors, the Score Engine,
   and the Decision Engine only produce/grade an `SSetupSignal`. They contain no
   broker calls. The single call site that may reach `CLS_SendMarketOrder()` is
   `CLS_ExecuteBasketOrder()` in `Execution/CLSAgent_BasketExecutor.mqh`. The
   actual `OrderSend()` call lives only inside `CLS_SendMarketOrder()` in
   `Execution/CLSAgent_OrderSender.mqh`. (Note: `CLSAgent.mq5` and
   `Memory/CLSAgent_TradeLog.mqh` mention the OrderSender by name in an
   `#include` and a comment respectively — neither is a call site.)

2. **The Risk Engine is never bypassed.** Every signal flows through
   `CLS_EvaluateRisk()` before Execution. `CLS_ExecuteBasketOrder()` is a silent
   no-op whenever `risk.isApproved` is false, and applies a further veto
   (`g_State.tradingAllowedByMode`, i.e. `Mode == CLS_MODE_AUTO_TRADE` **and**
   `AutoTrade == true`) on top of approval. Position Management only ever
   modifies/closes positions this same EA already opened.

## Trade traceability

Every order carries a per-setup magic number
(`CLS_MAGIC_BASE = 10240` + a per-setup offset, see
`Core/CLSAgent_Constants.mqh`), so any executed trade in `trades.csv` can be
traced back to the setup that produced it, and cross-checked against the
`journal.csv` row for the same bar. The risk audit tooling in this readiness
layer relies on exactly this property
(see [RISK_BOUNDARY_AUDIT.md](RISK_BOUNDARY_AUDIT.md)).

## What this review does not change

Nothing. This document is descriptive. The readiness layer adds documentation
and read-only helper scripts around the EA; it does not modify `MQL5/**`. Any
real compile issue found during verification is reported first
(see [COMPILE_VERIFICATION.md](COMPILE_VERIFICATION.md)), never silently
patched.
