# Contributing to CLS Agent

Thank you for your interest in CLS Agent. This repository is owned and
administered solely by [`alikhande70`](https://github.com/alikhande70).
External contributions are welcome as **suggestions**, but the owner
retains full and final control over what gets merged, when, and how.

## What we accept

- **Bug reports** — unexpected behavior in any module.
- **Compile error reports** — errors encountered compiling in MetaEditor.
- **Backtest reports** — Strategy Tester results, including settings and
  symbol/timeframe used.
- **Documentation improvements** — clarifications, typo fixes, better
  explanations of existing behavior.
- **Strategy suggestions** — ideas for new setups, scoring factors, or
  detection logic.
- **Risk management suggestions** — ideas to improve position sizing,
  loss protection, or basket risk controls.
- **Execution safety suggestions** — ideas to improve order-sending
  robustness, retry behavior, or broker-mechanics handling.

Please use the appropriate Issue template, or open a Discussion if your
suggestion doesn't fit a bug report.

## Code contributions

- All code changes must be submitted through a **Pull Request**. Direct
  pushes to `main` are not permitted for non-admin contributors.
- Pull Requests are **not merged automatically** — every PR is reviewed
  and merged at the owner's discretion.
- Contributions must preserve the existing modular architecture
  (Core / Market / Strategy / Risk / Execution / Memory / Reporting).
  Do not collapse modules together or restructure folders without prior
  discussion.
- Do not move trading/decision logic into `OnTick()`. `OnTick()` must
  remain a thin orchestrator that calls into the pipeline stages.
- Do not allow the Strategy layer (setup detectors, score engine) to
  execute trades directly. Only the Execution layer
  (`CLS_ExecuteBasketOrder()` / `CLS_SendMarketOrder()`) may ever call
  `OrderSend()`.
- Do not bypass the Risk Engine. Every order must still be approved by
  `RiskEngine` before reaching execution.
- Do not weaken any existing safety rule (e.g. `CLS_NO_ADD_TO_LOSING_BASKET`,
  `CLS_LLM_CAN_SEND_ORDERS`, `CLS_ENTRY_REQUIRES_CLOSED_BAR`, loss-streak
  protection).
- Do not add hidden broker credentials, account numbers, API keys, or
  other secrets anywhere in the codebase.
- Do not add any code path that allows an LLM or other external agent to
  send orders directly. Rule #1 — the LLM never sends orders — is
  structural, not a flag, and must stay that way.
- Do not change the default `InpMode` away from `CLS_MODE_SIGNAL_ONLY`,
  and do not change the default `InpAutoTrade` away from `false`.
  Attaching the EA with no input changes must never be able to place an
  order.
- Do not enable `InpSuperBurst` by default, and do not make it easier to
  enable in a live/demo context (e.g. via a separate "live mode" preset).
  It is an advanced override that bypasses `InpMaxOrdersPerBasket` and
  must stay an explicit, deliberate opt-in.

## Out of scope without prior discussion

Large refactors, new external dependencies, or anything that changes the
project's overall architecture should be raised in a Discussion first,
before investing time in a Pull Request.
