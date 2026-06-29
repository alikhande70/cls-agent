# QuickProfitMode Strategy Profile — Design Specification

> **Status: design / specification only.** This document describes a *proposed*
> optional strategy profile. **Nothing here is implemented.** No inputs, enums,
> CSV columns, or scripts are added by the PR that introduces this document.
> Implementation is a later, **owner-approved, gate-based** effort.
>
> **No profitability is claimed.** Every performance expectation in this document
> is **PENDING BACKTEST / PENDING DEMO VALIDATION**.
>
> **Governing rule:** QuickProfitMode must be **additive and optional**. It must
> not remove, overwrite, weaken, or silently change the existing baseline
> strategy behavior. Baseline remains available **permanently** until backtest
> evidence proves a better alternative.

## 1. Purpose
Define an optional second strategy "personality" — **QuickProfitMode** — that can
run *alongside* the current strategy (**Baseline/Classic**) so the two can be
**A/B backtested** under identical conditions and compared on evidence. The aim
is a more-active, quick-profit style **without** replacing or weakening the
proven baseline and **without** increasing account risk.

## 2. User risk-profile interpretation
The user's "risk 50–60%" means **user risk profile = 50–60 / 100** (a
balanced-active *trading personality*), **NOT** risking 50–60% of account
equity/balance/margin. It is not per-trade risk. It implies: not ultra-strict,
not reckless; more frequent small-profit opportunities and faster profit
protection — while capital protection stays fully governed by the deterministic
Risk Engine. No account-risk or lot-sizing increase is implied.

## 3. Dual-strategy requirement
The EA keeps **both** profiles simultaneously:
- **Baseline/Classic** — the current logic exactly as-is; the reference for all
  comparisons.
- **QuickProfitMode** — an optional, more-active personality.

A single input selects the active profile. The goal is clean A/B testing to
decide whether to keep, improve, disable, or further optimize QuickProfitMode —
**not** to fork or rewrite the EA.

## 4. Baseline / Classic Mode definition
Current setup logic (A→B→C→D priority, first valid wins), current score
thresholds (Gold 65 / Forex 60), current exits (breakeven & 50% partial-exit at
1.0R, ATR trailing at 1.5R), the current Risk Engine, and the current
Strategy/Risk/Execution separation. This is the permanent reference profile.

## 5. QuickProfitMode definition
Same setups, the same Decision → Risk → Execution path, and the same account-risk
controls, but with: an optionally lower (mode-aware) score threshold;
**earlier/faster profit protection** via a Hybrid Quick Profit Lock; faster
trailing; and **new anti-overtrading frequency guards**. It never sends orders
itself, never bypasses Decision/Risk/Execution, never changes AutoTrade defaults,
and never raises account risk.

## 6. Default behavior and safety defaults
- **Default = Baseline.** QuickProfitMode is **disabled unless explicitly
  enabled** by input.
- Unchanged in both profiles: `Mode = SIGNAL_ONLY`, `AutoTrade = false`,
  `InpBasketRiskPercent = 0.30`, `InpMaxDailyLossPercent = 1.00`,
  `InpSuperBurst = false`.
- Enabling QuickProfitMode with its adjustment/guards left at neutral defaults
  should still reproduce baseline behavior until the user opts into the
  more-active values.

## 7. Rule: Baseline behavior must remain identical
**Baseline trading decisions and EA behavior must remain identical. Reporting
metadata may be additively extended only if it does not alter trading behavior.**

Implementation pattern: a **profile settings resolver** returns an
effective-settings struct; for Baseline it returns exactly today's
inputs/constants, and **all QuickProfit-only logic is gated** so it is skipped
entirely in Baseline (no new branch alters the baseline decision path).
Verification later: a Baseline `SIGNAL_ONLY` run must reproduce the pre-change
`journal.csv` *trading decisions*; any added reporting metadata must be
non-behavioral.

## 8. Proposed `InpStrategyProfile` concept
A single selector input (proposed; **not added by this PR**):

```
enum ENUM_CLS_STRATEGY_PROFILE { CLS_PROFILE_BASELINE = 0, CLS_PROFILE_QUICK_PROFIT = 1 };
input ENUM_CLS_STRATEGY_PROFILE InpStrategyProfile = CLS_PROFILE_BASELINE; // default safe
```

The profile affects **only configurable behavior**: score-threshold adjustment,
exit profile, profit-lock, trailing, max-trades/cooldowns, and optional
setup-specific behavior. It must **not** enable Strategy order sending or bypass
DecisionEngine / RiskEngine / Execution.

## 9. Shared parameters between modes (identical in both)
Symbol/asset detection, sessions, spread caps, ATR regime, setup-detection math,
magic-number layout, `InpBasketRiskPercent`, `InpMaxOrdersPerBasket`,
`InpMaxDailyLossPercent`, `InpSuperBurst`, news guard, Execution mechanics
(retries / filling mode / slippage), and the Mode/AutoTrade gate.

## 10. QuickProfitMode-only parameters (inert in Baseline)
Proposed (not added yet): a score-threshold delta (≤ 0, default 0); profit-lock
triggers and protected-profit milestones (money- and/or R/points-based); faster
trailing trigger/step; max trades per day; max trades per symbol per day; max
concurrent positions; cooldown bars after loss (optionally shorter after win);
and an optional "QuickProfit setups mask" to restrict QuickProfitMode to selected
setups. All default to inert / unlimited / off, so their mere existence changes
nothing in Baseline.

## 11. Setup A/B/C/D behavior in Baseline
Unchanged: **A** Asian Sweep, **B** Daily Hunt, **C** FVG Fill, **D** BMS
Continuation — same triggers, thresholds, rawStrength grading, priority order,
and exits as today.

## 12. Setup A/B/C/D proposed behavior in QuickProfitMode (to be validated)
- **A / B (liquidity sweeps):** good quick-scalp fit; benefit most from earlier
  profit-lock.
- **C (FVG Fill):** highest raw frequency but **noisiest**; apply any lowered
  threshold here most cautiously — candidate for setup-mask exclusion or a
  stricter quick exit.
- **D (BMS Continuation):** rarest (two-phase arm→pullback); QuickProfitMode
  mainly changes its exit, not its trigger.

The score delta may apply to all setups or, via the mask, only to selected ones —
decided by per-setup A/B evidence (§20). **PENDING BACKTEST.**

## 13. Exit behavior comparison
- **Baseline exit:** SL/TP from the setup; breakeven and 50% partial at 1.0R;
  ATR trail at 1.5R; minimum trail step 50 points. (Unchanged.)
- **QuickProfit exit (proposed):** protection begins **earlier** (e.g. ~0.5–0.7R
  or at a money milestone); a protected-profit ladder; faster / structure
  trailing; optional **stall exit** (tighten or close if the move stops
  progressing). Always **additive to — never a deletion of —** the existing TP.

## 14. Hybrid Quick Profit Lock concept
A configurable, deterministic profit-lock that operates **only** by moving the
stop-loss in the *protective* direction through the existing
`CLS_ModifyPositionStops()` path (Execution boundary intact):

1. Initial SL from the current setup/risk logic.
2. When the trade reaches a minimum profit trigger, move SL to a
   **protected-profit** level.
3. At higher profit milestones, raise the protected level.
4. If price keeps moving, **trail** behind closed candle / structure / ATR.
5. If the trade stalls, tighten the stop or exit.
6. Everything deterministic and Risk-Engine compatible.

Hard rules: never loosen or widen SL; never violate the broker's stops/freeze
level; **never remove or shorten TP** (TP remains the upside target — the lock
only protects realized gains if price reverses). In Baseline this logic is
disabled and the current breakeven/partial/trailing remain exactly as-is.

## 15. Profit-lock examples (illustrative only — not hardcoded)
Configurable concept in account currency:

| Floating profit reaches ~ | Protect ~ |
|---|---|
| $6 | $5 |
| $10 | $8 |
| $15 | $12 |

If price keeps moving, trail behind candle/structure/ATR; if it turns back, close
with the protected profit instead of waiting for full TP. These figures are
**examples only** — real values will be configurable and tuned by backtest.

> **Money-based caveat:** `$` thresholds depend on lot size (a $6 lock means very
> different things at 0.01 vs 1.0 lots). A money-based lock must be documented and
> ideally normalized (e.g. per-0.01-lot, or as a fraction of the risked amount) so
> it behaves consistently across position sizes. An R/points-based variant avoids
> this dependency. A hybrid supports both.

## 16. Frequency guardrails (QuickProfitMode only)
Deterministic caps consulted **only when QuickProfitMode is active**: max trades
per day, max trades per symbol per day, max concurrent positions, cooldown after
loss (optionally a shorter cooldown after win). They produce **new Risk Engine
reject reasons** — they only ever *block* trades, never create or size them — and
are inert in Baseline, so baseline frequency is unchanged. They are the
responsible counterweight to a more-active entry profile (no uncontrolled
overtrading).

## 17. Risk Engine compatibility
The profit-lock acts through Position Management's existing SL-modify path; the
frequency guards are additional Risk Engine rejections layered *before* approval.
Both preserve the invariant: **Strategy never sends; Risk approves before
Execution; Execution is the only broker path.** No account-risk increase; the
basket / daily-loss / no-add-to-losing / spread / news / session gates are
unchanged in both profiles.

## 18. One-EA-per-chart multi-symbol policy
The current architecture uses single-symbol-per-chart state (e.g. the BMS setup
state, level cache, symbol profile, and runtime state are single-symbol
singletons), and per-symbol cleanup assumes one symbol per instance. Therefore:
**run one EA instance per symbol/chart.** A true multi-symbol manager is **not**
in scope and is **not** part of QuickProfitMode; it would require per-symbol state
and is a separate future architecture effort. Confluence scoring across setups is
likewise deferred.

## 19. Required logging/reporting for A/B testing
To make A/B comparison unambiguous, tag runs/rows with the active profile
(proposed for a later phase, **not added by this PR**): a `strategyProfile` field
on the decision journal and trade log, an optional `exitProfile` on the trade log
(how a trade closed: TP / SL / breakeven / trail / profit-lock / stall), and a
profile line in the backtest summary. These are **reporting metadata only** and
must not alter trading behavior. Any such CSV extension is additive (existing
columns and their meaning are preserved).

## 20. Backtest comparison plan — Baseline vs QuickProfitMode
Run **A (Baseline)** and **B (QuickProfitMode)** with **identical** symbol,
timeframe, date range, spread model, deposit, and risk inputs — only the profile
differs. Measure for each:

- trade count, win rate, profit factor, max drawdown
- average profit, average loss, average holding time
- per-setup (A/B/C/D) performance
- daily trade frequency, per-symbol performance
- risk-boundary audit result

Then compare: Does QuickProfitMode increase trade count? Reduce holding time?
Improve or hurt profit factor? Reduce or increase drawdown? Create overtrading?
Which setup benefits and which becomes noisy? Is the profit-lock helping or
cutting winners too early? Should QuickProfitMode apply to all setups or only
selected ones? Use the existing read-only tooling
(`scripts/validate_cls_backtest_package.py`, `scripts/audit_cls_risk_boundary.py`,
`scripts/review_cls_performance.py`) on each package. **All results PENDING
BACKTEST / PENDING DEMO VALIDATION.**

## 21. Acceptance criteria for keeping QuickProfitMode (engineering, not profit)
Keep QuickProfitMode only if, on the same data: the risk-boundary audit still
**PASS**es; drawdown does not worsen beyond an agreed margin; trade frequency
increases **while** profit factor is maintained or improved; the profit-lock does
not collapse profit factor by cutting winners; and frequency caps demonstrably
prevent overtrading. These are **engineering readiness** criteria, not a
profitability claim — **PENDING BACKTEST / PENDING DEMO VALIDATION**.

## 22. Criteria for rejecting or modifying QuickProfitMode
Reject or modify if QuickProfitMode materially worsens profit factor, increases
drawdown, yields a risk-audit **FAIL**, or merely adds noise (especially via
Setup C). Modification paths: restrict to selected setups (mask), raise the score
delta back toward baseline, lengthen cooldowns, or tune profit-lock triggers.
Baseline remains the fallback regardless.

## 23. Proposed implementation phases (each MQL5-touching phase is owner-approved, gated)
- **P0 (this PR) — docs only:** add this design document. No code.
- **P1:** add the profile enum + settings resolver + inert inputs; static safety
  scan + compile; prove Baseline trading decisions unchanged.
- **P2:** Hybrid Quick Profit Lock (QuickProfit-gated) + earlier triggers.
- **P3:** frequency guards + cooldown (QuickProfit-gated; new reject reasons).
- **P4:** reporting metadata (profile/exit tagging) + doc/validator header update.
- **P5:** A/B backtests + risk audits + performance review; decide keep / modify
  / reject.

## 24. Files likely to change later (NOT in this PR)
`Core/CLSAgent_Inputs.mqh` (profile + QuickProfit-only inputs);
`Core/CLSAgent_Types.mqh` (profile enum, reject reasons, optional exit-profile
enum); `Core/CLSAgent_State.mqh` (frequency counters / cooldown);
`Strategy/CLSAgent_DecisionEngine.mqh` / `CLSAgent_ScoreEngine.mqh` (mode-aware
threshold); `Execution/CLSAgent_PositionManager.mqh` + `CLSAgent_Trailing.mqh`
(plus a possible new `CLSAgent_ProfitLock.mqh`); `Risk/CLSAgent_RiskEngine.mqh`
(frequency / cooldown gates); `Memory/CLSAgent_Journal.mqh` +
`CLSAgent_TradeLog.mqh` (reporting metadata); `Reporting/CLSAgent_BacktestReport.mqh`
(summary line). Docs/tooling: `docs/BACKTEST_OUTPUTS.md` and
`scripts/validate_cls_backtest_package.py` known headers (additive).

## 25. Files that must not change
The Strategy → Risk → Execution boundary; baseline trading behavior and defaults
(`SIGNAL_ONLY`, `AutoTrade = false`, basket / daily-loss / SuperBurst);
account-risk and lot-sizing logic. Strategy must never call order functions; no
Decision/Risk/Execution bypass; no change to AutoTrade defaults.

## 26. Safety boundaries
- QuickProfitMode is **additive and optional**; **Baseline remains the default**.
- **Baseline trading behavior must remain unchanged.**
- QuickProfitMode is **disabled unless explicitly enabled**.
- **No profitability is claimed**; all performance assumptions are **PENDING
  BACKTEST / PENDING DEMO VALIDATION**.
- LLM / MCP / Companion must **never** send orders, enable AutoTrade, or bypass
  the Risk Engine.
- **Strategy must never send orders.**
- **Risk must approve before Execution.**
- **Execution remains the only broker path.**
- **Live trading remains gate-based and human-approved.**

## 27. Final recommendation
Implement QuickProfitMode as a **clean strategy-profile layer** keyed by
`InpStrategyProfile` (default `CLS_PROFILE_BASELINE`), with **all** QuickProfit
behavior gated so Baseline trading decisions and behavior remain identical
(reporting metadata may be additively extended only if non-behavioral). Keep
Baseline permanently; add profile tagging for clean A/B logging; run
identical-conditions Baseline-vs-QuickProfit backtests; and keep QuickProfitMode
**only** on evidence. One EA instance per symbol/chart; confluence scoring and
multi-symbol management remain deferred. No profitability or live-readiness is
asserted — **PENDING BACKTEST / PENDING DEMO VALIDATION**.
