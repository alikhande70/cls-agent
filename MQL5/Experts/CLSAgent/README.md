# CLS Agent v2.4+ — Decision-Safe Contextual Liquidity Scalping Agent

Modular MQL5 Expert Advisor for scalping Gold (`XAUUSD` / `XAUUSDm` / `GOLD`) and the
major Forex pairs (`EURUSD`, `GBPUSD`, `USDJPY`) using a Basket Burst approach. All
entry, risk and basket-management decisions are made by deterministic, rule-based
code inside the EA. An LLM may analyze, review and report on the EA's behavior, but
it never sends an order — that boundary is enforced in code, not just by convention.

## Build status

**Part 1 of 10 — Project Skeleton + Core Types + Inputs + Constants + Main EA Shell.**

Implemented in this part:
- Folder skeleton for every future module (`Market/`, `Strategy/`, `Risk/`,
  `Execution/`, `Memory/`, `Reports/`, `Tests/`) and the `Files/CLSAgent/` runtime
  output tree (`logs/`, `reports/`, `state/`).
- `Core/CLSAgent_Constants.mqh` — fixed safety constants (e.g.
  `CLS_NO_ADD_TO_LOSING_BASKET`, `CLS_LLM_CAN_SEND_ORDERS`), magic-number layout.
- `Core/CLSAgent_Types.mqh` — shared enums (`ENUM_CLS_MODE`, `ENUM_CLS_SETUP_TYPE`,
  `ENUM_CLS_REJECT_REASON`, ...) and the data-contract structs passed between
  pipeline stages (`SSetupContext`, `SSetupSignal`, `SScoreResult`, `SRiskDecision`,
  `SBasketInfo`).
- `Core/CLSAgent_Inputs.mqh` — every EA input, grouped by module.
- `Core/CLSAgent_State.mqh` — runtime state (`g_State`), closed-bar detection,
  daily-rollover detection.
- `Core/CLSAgent_Utils.mqh` — centralized logging (`CLS_Log`) and small helpers.
- `CLSAgent.mq5` — the EA shell: `OnInit`/`OnTick`/`OnDeinit`, input validation,
  Gold-vs-Forex auto-detection, and one named stub function per pipeline stage
  (Context Engine → Setup Detector → Score Engine → Risk Engine → Basket
  Execution → Position Manager → Journal → Report/LLM Review). The stubs are
  empty — they exist so the pipeline's shape and call order are fixed from Part 1
  onward; later parts fill in their bodies without changing `CLSAgent.mq5` itself.

Not implemented yet (later parts, do not edit ahead of schedule):
Market context, setup detection, scoring, risk engine, basket execution, position
management, journal/adaptive state, and reporting/backtest export.

## Folder map

```
MQL5/
├── Experts/CLSAgent/CLSAgent.mq5   <- compile this file in MetaEditor
└── Include/CLSAgent/
    └── Core/                       <- Part 1 (this part)
        ├── CLSAgent_Constants.mqh
        ├── CLSAgent_Types.mqh
        ├── CLSAgent_Inputs.mqh
        ├── CLSAgent_State.mqh
        └── CLSAgent_Utils.mqh
```

## Installing into MetaTrader 5

1. Open MetaTrader 5 → `File` → `Open Data Folder`.
2. Copy this repo's `MQL5/Include/CLSAgent` folder into `<DataFolder>/MQL5/Include/`.
3. Copy this repo's `MQL5/Experts/CLSAgent` folder into `<DataFolder>/MQL5/Experts/`.
4. Copy this repo's `MQL5/Files/CLSAgent` folder into `<DataFolder>/MQL5/Files/`.
5. In MetaEditor, open `CLSAgent.mq5` and press **F7** (Compile).
6. In MT5, attach `CLSAgent` from Navigator → Expert Advisors onto a chart for
   `XAUUSD`, `EURUSD`, `GBPUSD` or `USDJPY`.

`Mode` defaults to `SIGNAL_ONLY` and `AutoTrade` defaults to `false`, so attaching
the EA right now cannot place any order — Part 1 has no execution logic at all yet.

See the repository root for the full project specification and the part-by-part
delivery plan.
