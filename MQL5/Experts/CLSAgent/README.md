# CLS Agent v2.4+ — Decision-Safe Contextual Liquidity Scalping Agent

Modular MQL5 Expert Advisor for scalping Gold (`XAUUSD` / `XAUUSDm` / `GOLD`) and the
major Forex pairs (`EURUSD`, `GBPUSD`, `USDJPY`) using a Basket Burst approach. All
entry, risk and basket-management decisions are made by deterministic, rule-based
code inside the EA. An LLM may analyze, review and report on the EA's behavior, but
it never sends an order — that boundary is enforced in code, not just by convention.

## Build status

**Parts 1-4 of 10 done — Project Skeleton, Market Foundation, Setup Detection, Score Engine.**

Implemented so far:
- **Part 1 — Core.** Folder skeleton for every module, fixed safety constants
  (`CLS_NO_ADD_TO_LOSING_BASKET`, `CLS_LLM_CAN_SEND_ORDERS`), shared enums/structs
  (`SSetupContext`, `SSetupSignal`, `SScoreResult`, `SRiskDecision`, `SBasketInfo`),
  every EA input grouped by module, runtime state (`g_State`), closed-bar/daily-
  rollover detection, centralized logging.
- **Part 2 — Market.** `SymbolProfile` (Gold-vs-Forex detection, broker trading
  constraints), `TimeSession` (Asian/London/NewYork/Overlap), `Indicators` (ATR
  handle lifecycle), `SpreadBuffer` (rolling tick-spread average), `ATRRegime`
  (LOW/NORMAL/HIGH/EXTREME volatility classification), `LevelCache` (previous-day
  and Asian-session high/low, recomputed once per broker day). Wired into the
  Context Engine stage (`BuildSetupContext()` in `CLSAgent.mq5`).
- **Part 3 — Strategy / Setup Detection.** `SetupContext` (shared candle-anatomy,
  fractal swing-pivot, Fair-Value-Gap and ATR-based stop/target helpers — every
  read enforces shift≥1, never the forming bar), and four deterministic setups:
  **A** Asian Sweep, **B** Daily Hunt (previous-day liquidity sweep), **C** FVG
  Fill (return-to-imbalance continuation), **D** BMS Continuation (break of
  structure + pullback entry, the one stateful setup). `SetupDetector` tries
  A→B→C→D in order and stops at the first valid signal. Wired into `OnTick()`
  directly (no stub remains for this stage).
- **Part 4 — Strategy / Score &amp; Decision Engine.** Every Setup A-D detector now
  also grades its own trigger quality into `signal.rawStrength` (0..1 — pierce
  depth/ATR for the sweeps, gap size/ATR for FVG Fill, breakout body/ATR for BMS).
  `ScoreEngine` combines that with three continuous context multipliers (session,
  ATR regime, spread-vs-cap) into a single multiplicative 0..100 score:
  `score = 100 * rawStrength * sessionFactor * atrFactor * spreadFactor`.
  `DecisionEngine` is a pure score gate — it accepts/rejects purely against
  `g_SymbolProfile.minScoreToTrade` (Rule #8: Gold and Forex each resolve their
  own threshold). The hard environmental gates from Rule #7 (spread/session/ATR
  regime/daily-loss) are *not* enforced here; they belong to the Risk Engine
  (Part 5), which still runs after this stage regardless of the verdict so every
  signal — accepted or rejected — reaches the Journal later (Rule #9). Wired into
  `OnTick()` directly (no stub remains for this stage).

Not implemented yet (later parts, do not edit ahead of schedule):
Risk Engine, Basket Execution, Position Management, Journal/adaptive state, and
Reports/backtest export.

## Folder map

```
MQL5/
├── Experts/CLSAgent/CLSAgent.mq5   <- compile this file in MetaEditor
└── Include/CLSAgent/
    ├── Core/                       <- Part 1
    │   ├── CLSAgent_Constants.mqh
    │   ├── CLSAgent_Types.mqh
    │   ├── CLSAgent_Inputs.mqh
    │   ├── CLSAgent_State.mqh
    │   └── CLSAgent_Utils.mqh
    ├── Market/                     <- Part 2
    │   ├── CLSAgent_SymbolProfile.mqh
    │   ├── CLSAgent_TimeSession.mqh
    │   ├── CLSAgent_Indicators.mqh
    │   ├── CLSAgent_SpreadBuffer.mqh
    │   ├── CLSAgent_ATRRegime.mqh
    │   └── CLSAgent_LevelCache.mqh
    └── Strategy/                   <- Parts 3-4
        ├── CLSAgent_SetupContext.mqh
        ├── CLSAgent_SetupDetector.mqh
        ├── CLSAgent_SetupA_AsianSweep.mqh
        ├── CLSAgent_SetupB_DailyHunt.mqh
        ├── CLSAgent_SetupC_FVGFill.mqh
        ├── CLSAgent_SetupD_BMSContinuation.mqh
        ├── CLSAgent_ScoreEngine.mqh     <- Part 4
        └── CLSAgent_DecisionEngine.mqh  <- Part 4
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
