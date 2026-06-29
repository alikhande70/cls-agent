# Agent / Companion / LLM / MCP Boundary

This document defines the **hard boundary** between the deterministic CLS Agent
EA and any Agent, LLM, MCP server, or "CLS Companion" tooling that interacts
with this repository. It is the governing safety contract for everything in the
readiness layer.

## The EA itself

**cls-agent is, and remains, a deterministic, rule-based MQL5 Expert Advisor.**
All entry, scoring, risk, sizing, and basket-management decisions are made by
code inside the EA.

cls-agent **may eventually trade on demo and live accounts** as a deterministic
EA — that future is not foreclosed. But it may only do so after the documented
readiness gates pass and a human explicitly approves:

- compile verification
- signal-only backtest
- Strategy Tester validation
- report validation
- demo readiness review
- demo forward testing
- risk review
- live-readiness gate
- explicit human approval

See [REAL_ACCOUNT_READINESS_GATE.md](REAL_ACCOUNT_READINESS_GATE.md) for the
full gate definitions. The limitation below is on **LLM / MCP / Companion
control**, not on the future of the deterministic EA.

## What Agent / LLM / MCP / Companion MAY do

They are limited to **review, analysis, testing, validation, reporting, and
readiness assessment**:

- read and explain the source code
- review architecture and module boundaries
- diagnose compile errors from provided logs
- validate exported backtest packages
- audit risk-boundary traceability from exported logs
- generate performance / demo-readiness / live-readiness reports
- propose patches and documentation (for human review)

## What Agent / LLM / MCP / Companion MUST NOT do

These are non-negotiable:

- **Must not send orders.** No LLM order sending. No Companion order sending. No
  MCP direct execution.
- **Must not bypass the Risk Engine.** Every order, from any path, must be
  approved by `CLS_EvaluateRisk()`.
- **Must not control the Execution layer.** The Execution layer is the only
  place allowed to reach broker execution, and it is driven only by the EA's own
  deterministic pipeline.
- **Must not enable AutoTrade automatically.** No automatic `InpAutoTrade = true`.
- **Must not activate live mode automatically.** No automatic
  `InpMode = CLS_MODE_AUTO_TRADE`.
- **Must not change live risk settings without explicit human approval.** No
  automatic changes to `InpBasketRiskPercent`, `InpMaxOrdersPerBasket`,
  `InpMaxDailyLossPercent`, or any other risk input on a live account.
- **Must not handle credentials/sessions/cookies/API keys.**
- **Must not auto-approve** any gate, promotion, or live activation.

## In-code anchor

The boundary is anchored in the EA's own compile-time constant:

```
// MQL5/Include/CLSAgent/Core/CLSAgent_Constants.mqh
#define CLS_LLM_CAN_SEND_ORDERS false  // Rule #1: LLM never sends orders
```

This is a constant, not an input, so it cannot be toggled on by configuration.
Combined with the structural rule that `OrderSend()` exists only in the
Execution layer (see [EA_ARCHITECTURE_REVIEW.md](EA_ARCHITECTURE_REVIEW.md)),
there is no code path by which an LLM, MCP server, or Companion can place an
order.

## Final boundary statement

Agent / LLM / MCP / Companion must **never** become:

- an execution controller
- an order sender
- a risk override
- an auto-trading operator

They remain review-and-report tools. The deterministic EA, after gates and
human approval, is the only thing that may ever trade.
