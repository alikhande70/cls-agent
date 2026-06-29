# Real Account Readiness Gate

This document defines the ordered gates CLS Agent must pass on its way toward
demo and (eventually) live trading. **No gate self-approves**, and the final
gate is an explicit human decision. The deterministic EA is the only thing that
may ever trade — Agent / LLM / MCP / Companion tooling only produces the
evidence and reports that inform each gate (see
[AGENT_COMPANION_BOUNDARY.md](AGENT_COMPANION_BOUNDARY.md)).

**Blocking** gates must pass before the next is attempted. **Advisory** gates
inform judgement but do not, on their own, halt progression.

> The verdicts produced here are **engineering readiness verdicts**, not
> financial advice. Profitability is never guaranteed.

---

## Gate 1 — Compile Verification

**Purpose:** Ensure the EA compiles cleanly before any tester/demo/live
progression.

**Acceptance:**
- MetaEditor compile completes with **0 errors**.
- Warnings are reviewed and documented.

**Required evidence/files:**
- `compile_log.txt` (copied MetaEditor compiler output)
- screenshot of the Errors tab (optional but recommended)
- commit hash of the source compiled
- EA version (`CLS_AGENT_VERSION`, currently `2.4.0`)

**Fail conditions:** any compile error.

**Expected output:** `compile_summary.md` + `compile_summary.json` from
`scripts/parse_metaeditor_compile_log.py`.

**Blocking.**

---

## Gate 2 — Signal-Only Test

**Purpose:** Confirm that with `Mode = SIGNAL_ONLY` and `AutoTrade = false`
(the defaults), the EA produces a decision journal but sends **no orders**.

**Acceptance:**
- A Strategy Tester run completes in SIGNAL_ONLY mode.
- `journal.csv` is produced and non-empty.
- `trades.csv` is empty or absent (no orders were sent).

**Required evidence/files:** the exported package (see
[BACKTEST_OUTPUTS.md](BACKTEST_OUTPUTS.md)) — at minimum `journal.csv`, and
`trades.csv` if any file exists.

**Fail conditions:** any trade recorded while configured signal-only; tester
crash/freeze.

**Expected output:** `validation.md` + `validation.json` from
`scripts/validate_cls_backtest_package.py --mode SIGNAL_ONLY`.

**Blocking.**

---

## Gate 3 — Strategy Tester Validation

**Purpose:** Validate a full Strategy Tester run with execution enabled in the
tester (`Mode = AUTO_TRADE`, `AutoTrade = true`), on a single primary
symbol/timeframe.

**Acceptance:**
- Run completes without crash/freeze.
- All expected outputs are produced (`journal.csv`, `trades.csv`,
  `baskets.csv`, `performance.csv`, `backtest_summary.txt`, plus the Strategy
  Tester `.htm`/`.html` report).
- `performance.csv` is parseable and internally consistent.

**Required evidence/files:** the full exported package.

**Fail conditions:** missing required outputs; unparseable `performance.csv`;
tester instability.

**Expected output:** `validation.md` + `validation.json` from
`scripts/validate_cls_backtest_package.py --mode AUTO_TRADE`.

**Blocking.**

---

## Gate 4 — Risk Engine Traceability

**Purpose:** Demonstrate, from exported evidence, that every executed trade was
approved by the Risk Engine and that no basket violated its configured limits.

**Acceptance:**
- Every row in `trades.csv` traces to a `journal.csv` row with
  `riskApproved=true` and `executed=true` for the same symbol/setup.
- No basket in `baskets.csv` exceeds the configured `InpMaxOrdersPerBasket`.
- No losing basket (`isLosing=true`) grew in order count
  (no-add-to-losing-basket rule).

**Required evidence/files:** `journal.csv`, `trades.csv`, `baskets.csv`,
`performance.csv`.

**Fail conditions:** any executed trade without a matching approved journal
row; any basket over the configured cap; any add to a losing basket.

**Expected output:** `risk_boundary_audit.md` + `risk_boundary_audit.json` from
`scripts/audit_cls_risk_boundary.py`. Insufficient evidence →
`INCONCLUSIVE`, not a pass.

**Blocking.**

---

## Gate 5 — Strategy / Execution Separation

**Purpose:** Confirm the two structural rules still hold in source: Strategy
never sends orders; `OrderSend()` lives only in Execution.

**Acceptance:**
- `OrderSend(` appears only under `MQL5/Include/CLSAgent/Execution/`.
- `MQL5/Include/CLSAgent/Strategy/` contains no order-sending calls.
- Safety constants (`CLS_NO_ADD_TO_LOSING_BASKET`, `CLS_LLM_CAN_SEND_ORDERS`)
  are present and unchanged.

**Required evidence/files:** the source tree (no run needed).

**Fail conditions:** any order-sending call outside Execution; a weakened or
removed safety constant.

**Expected output:** `safety_scan.md` + `safety_scan.json` from
`scripts/static_safety_scan.py`.

**Blocking** (and re-runnable continuously, including in CI, since it needs no
broker/run).

---

## Gate 6 — Multi-Symbol / Multi-Timeframe Backtest

**Purpose:** Check behavior generalizes beyond one symbol/timeframe.

**Acceptance:**
- Strategy Tester packages exist for the primary symbols (`XAUUSD` and the
  Forex majors) and at least two timeframes (e.g. M5, M15).
- Each package passes Gate 3 validation.

**Required evidence/files:** one validated package per symbol/timeframe.

**Fail conditions:** validation failure on any required package; behavior that
only holds for a single configuration.

**Expected output:** one `validation.*` set per package.

**Advisory → blocking** (advisory while exploring; blocking before demo).

---

## Gate 7 — Performance Risk Review

**Purpose:** Engineering review of risk-relevant performance characteristics.

**Acceptance:**
- Sufficient trade sample size.
- Drawdown within a documented tolerance.
- No single setup concentrating all the risk/return.
- No evidence of uncontrolled basket risk.

**Required evidence/files:** `performance.csv` (and `trades.csv` if available).

**Fail conditions:** verdict `REJECT_FOR_NOW`; data too thin → `INCONCLUSIVE`.

**Expected output:** performance report (`.md` + `.json`) from
`scripts/review_cls_performance.py` with verdict in
`PASS_TO_DEMO` / `NEEDS_REVIEW` / `REJECT_FOR_NOW` / `INCONCLUSIVE`.

**Advisory** (informs the demo decision; a human makes the call).

---

## Gate 8 — Demo Forward Testing

**Purpose:** Validate on a live-data demo account over a meaningful sample,
under real spread/slippage/broker behavior.

**Acceptance:**
- Demo forward run over a meaningful number of trades.
- Exported demo logs pass Gates 4 and 7.
- Broker execution behavior (requotes, partial fills, freeze level) reviewed.

**Required evidence/files:** demo `journal.csv` / `trades.csv` / `baskets.csv` /
`performance.csv`.

**Fail conditions:** risk-traceability failure on demo data; unacceptable
divergence from backtest expectations.

**Expected output:** demo readiness report; see
[DEMO_READINESS.md](DEMO_READINESS.md).

**Blocking.**

---

## Gate 9 — Live Risk Caps

**Purpose:** Before any live consideration, confirm conservative risk caps are
explicitly set and documented for the live account.

**Acceptance:**
- `InpBasketRiskPercent`, `InpMaxOrdersPerBasket`, and `InpMaxDailyLossPercent`
  are explicitly chosen, documented, and within conservative bounds.
- `InpSuperBurst` is `false`.
- The intended live values are recorded alongside the demo evidence.

**Required evidence/files:** a written risk-cap record reviewed by the owner.

**Fail conditions:** undocumented or aggressive caps; any automated change to
these values (forbidden — see
[AGENT_COMPANION_BOUNDARY.md](AGENT_COMPANION_BOUNDARY.md)).

**Expected output:** a documented, human-signed risk-cap statement.

**Blocking.**

---

## Gate 10 — Human Live Approval

**Purpose:** Final, explicit human authorization to run on a real account.

**Acceptance:**
- All blocking gates above passed with evidence on record.
- The repository owner explicitly approves live activation.
- `Mode = AUTO_TRADE` and `AutoTrade = true` are set **manually by a human** on
  the live account.

**Required evidence/files:** the complete evidence trail (Gates 1–9) plus an
explicit owner approval.

**Fail conditions:** any missing blocking gate; any attempt to activate live
mode automatically (forbidden).

**Expected output:** a human-approved live-activation record.

**Blocking.** No tool, agent, LLM, MCP server, or Companion may satisfy this
gate — only a human can.
