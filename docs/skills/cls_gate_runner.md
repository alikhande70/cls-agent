---
name: cls-gate-runner
description: Running the CLS Agent readiness gates and validation scripts in the correct order with complete evidence. Use when executing the MT5_INSTALL_COMPILE_BACKTEST_RUNBOOK.
---

# CLS Agent gate runner

## Fixed order — never skip or reorder
compile (1) → Signal-Only (2) → Baseline backtest (3) → risk-boundary audit (4)
→ static safety scan (5) → multi-symbol/timeframe (6) → performance review (7).
Stop and report after EACH gate.

## Per-gate inputs
- Gate 2 (Signal-Only): InpStrategyProfile=CLS_PROFILE_BASELINE, InpMode=CLS_MODE_SIGNAL_ONLY,
  InpAutoTrade=false. EXPECTED RESULT: a populated decision journal with ZERO trades.
  If any trade appears in Signal-Only → FAIL → STOP.
- Gate 3 (Baseline): same profile; AutoTrade=true ONLY inside the tester (historical
  simulation, never a real/demo account).

## Validation scripts — documented flags only, do not invent flags
- parse_metaeditor_compile_log.py : --out --json-out --commit --timestamp
- validate_cls_backtest_package.py : --mode {SIGNAL_ONLY,AUTO_TRADE} --out --json-out
- audit_cls_risk_boundary.py : --max-orders-per-basket --max-basket-risk-percent --source-root --out --json-out
- review_cls_performance.py : --min-sample --min-profit-factor --max-concentration --max-drawdown --out --json-out
- static_safety_scan.py : --root --out --json-out

## Evidence layout (keep complete; never overwrite Baseline with QuickProfit)
evidence/baseline/<symbol>/<timeframe>/<date-range>/ containing:
journal.csv, trades.csv, baskets.csv, performance.csv, backtest_summary.txt,
<StrategyTesterReport>.htm, and the *_summary.md/.json + audit/review outputs.
