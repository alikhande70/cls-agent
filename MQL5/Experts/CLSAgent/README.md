# CLS Agent v2.4+ — Decision-Safe Contextual Liquidity Scalping Agent

Modular MQL5 Expert Advisor for scalping Gold (`XAUUSD` / `XAUUSDm` / `GOLD`) and the
major Forex pairs (`EURUSD`, `GBPUSD`, `USDJPY`) using a Basket Burst approach. All
entry, risk and basket-management decisions are made by deterministic, rule-based
code inside the EA. An LLM may analyze, review and report on the EA's behavior, but
it never sends an order — that boundary is enforced in code, not just by convention.

## Build status

**Parts 1-7 of 10 done — Project Skeleton, Market Foundation, Setup Detection, Score Engine, Risk Engine, Basket Execution, Position Management.**

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
- **Part 5 — Risk / Risk Engine.** `DailyLimits` (current daily loss % vs.
  `InpMaxDailyLossPercent`, baseline captured once per broker day), `NewsGuard`
  (manual `"YYYY.MM.DD HH:MM-HH:MM;..."` blackout windows, v1 has no economic-
  calendar integration), `BasketRisk` (scans live positions filtered by this
  chart's symbol + magic-number range + direction — no separately maintained
  tally that could drift from the broker's own book — to read the current
  basket's order count and floating P/L), `LotCalculator` (lot size from
  equity × risk% ÷ stop distance, normalized down to the broker's volume step,
  never rounded up past the requested risk). `RiskEngine` orchestrates all four:
  re-checks the Rule #7 hard gates the Score Engine deliberately left ungated
  (spread/session/ATR regime), adds DailyLoss and NewsGuard, enforces Rule #5
  (`CLS_NO_ADD_TO_LOSING_BASKET`, always true) and Rule #3/#4 (the whole
  basket's risk target is fixed at `InpBasketRiskPercent` and split evenly
  across `InpMaxOrdersPerBasket` slots, so total basket risk never grows as
  more orders are added — only how many slots are already filled). Wired into
  `OnTick()` directly (no stub remains for this stage).
- **Part 6 — Execution / Basket Execution.** `OrderSender` is a pure
  broker-mechanics layer: builds one `MqlTradeRequest`, resolves the broker's
  supported filling mode (FOK → IOC → RETURN), re-validates the stop/target
  distance against the live stops/freeze level on every attempt (price moves
  between retries), and retries up to `InpOrderRetryCount` times
  (`InpOrderRetryDelayMs` apart) — but only on transient retcodes
  (requote/timeout/price-changed/connection); a non-retryable rejection
  (invalid stops, no money, trading disabled) returns immediately instead of
  wasting retries on a result that cannot change. `BasketExecutor` is the
  policy layer: it acts only on a signal the Risk Engine already approved,
  applies the final veto (`g_State.tradingAllowedByMode`, i.e.
  `Mode=AUTO_TRADE` *and* `AutoTrade=true`), derives the per-setup magic
  number from `CLSAgent_Constants.mqh`'s magic-offset layout, and is the
  single call site in the whole project that may ever reach
  `CLS_SendMarketOrder()` — Rule #1 (the LLM never sends orders) is enforced
  structurally by that exclusivity, not by a runtime flag. Wired into
  `OnTick()` directly (no stub remains for this stage).
- **Part 7 — Execution / Position Management.** `Trailing` is a pure
  calculation helper (`CLS_ComputeTrailingStop()`) — no broker calls — that
  returns a candidate SL only when it strictly improves on the current one by
  at least `InpTrailingStopStepPoints`. `PartialExit` closes
  `InpPartialExitPercent` of a position exactly once, the first time it
  reaches `InpPartialExitTriggerR`; since that "already done" fact cannot be
  read back from the broker once the position's volume has changed, it is the
  one place in the project that keeps its own small, ephemeral
  ticket cache (`g_PartialExitedTickets[]`, pruned every pass, lost on EA
  restart — Part 8 adds real persistence) instead of re-deriving everything
  from live broker state the way `BasketRisk` does. `PositionManager`
  (`CLS_ManageOpenPositions()`) is the orchestrator: once per closed bar it
  scans this chart's own open positions (same symbol + magic-range filter as
  `BasketRisk`) and applies, in order, Breakeven → Partial Exit → Trailing,
  reusing `OrderSender`'s new mechanics-only `CLS_ModifyPositionStops()` /
  `CLS_ClosePositionPartial()` (neither retries — Position Management
  re-evaluates and retries on its own next pass instead of blocking the
  tick). Progress through each stage is measured in R-multiples off a
  deliberately stateless approximation, `oneR = ctx.atrValue *
  InpStopLossATRMultiplier`, rather than caching each position's exact
  original stop distance. Wired into `OnTick()` directly (no stub remains for
  this stage) — runs every closed bar regardless of whether a new signal
  fired that bar, since existing open positions still need managing.

Not implemented yet (later parts, do not edit ahead of schedule):
Journal/adaptive state and Reports/backtest export.

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
    ├── Strategy/                   <- Parts 3-4
    │   ├── CLSAgent_SetupContext.mqh
    │   ├── CLSAgent_SetupDetector.mqh
    │   ├── CLSAgent_SetupA_AsianSweep.mqh
    │   ├── CLSAgent_SetupB_DailyHunt.mqh
    │   ├── CLSAgent_SetupC_FVGFill.mqh
    │   ├── CLSAgent_SetupD_BMSContinuation.mqh
    │   ├── CLSAgent_ScoreEngine.mqh
    │   └── CLSAgent_DecisionEngine.mqh
    ├── Risk/                       <- Part 5
    │   ├── CLSAgent_RiskEngine.mqh
    │   ├── CLSAgent_BasketRisk.mqh
    │   ├── CLSAgent_LotCalculator.mqh
    │   ├── CLSAgent_DailyLimits.mqh
    │   └── CLSAgent_NewsGuard.mqh
    └── Execution/                  <- Parts 6-7
        ├── CLSAgent_BasketExecutor.mqh
        ├── CLSAgent_OrderSender.mqh
        ├── CLSAgent_PositionManager.mqh
        ├── CLSAgent_PartialExit.mqh
        └── CLSAgent_Trailing.mqh
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
the EA right now cannot place any order regardless of how Basket Execution
(Part 6) is configured — both `Mode=AUTO_TRADE` and `AutoTrade=true` must be
set explicitly before `CLS_ExecuteBasketOrder()` will ever call `OrderSend()`.
Position Management (Part 7) only ever modifies/partially-closes positions
this same EA already opened, so it carries no extra gate beyond that.

See the repository root for the full project specification and the part-by-part
delivery plan.
