# Readiness Roadmap

This roadmap maps the project's current validation status onto the readiness
gates that lead toward demo and (eventually) live trading. It complements
[ROADMAP.md](../ROADMAP.md) (version milestones) and
[REAL_ACCOUNT_READINESS_GATE.md](REAL_ACCOUNT_READINESS_GATE.md) (gate
definitions).

## Current status — recorded honestly

No verification evidence exists in this repository yet. The following are marked
**PENDING** because there is no artifact proving otherwise. They are not marked
as passed or failed — only as not-yet-evidenced.

| Gate | Status | Evidence on record |
|---|---|---|
| 1. Compile Verification | **PENDING** | none — no `compile_log.txt` committed |
| 2. Signal-Only Test | **PENDING** | none — no SIGNAL_ONLY package committed |
| 3. Strategy Tester Validation | **PENDING** | none |
| 4. Risk Engine Traceability | **PENDING** | none — requires exported logs |
| 5. Strategy / Execution Separation | **CODE-VERIFIED (static)** | confirmed by review + `static_safety_scan.py`; see [EA_ARCHITECTURE_REVIEW.md](EA_ARCHITECTURE_REVIEW.md) |
| 6. Multi-Symbol / Multi-Timeframe Backtest | **PENDING** | none |
| 7. Performance Risk Review | **PENDING** | none |
| 8. Demo Forward Testing | **NOT STARTED** | none |
| 9. Live Risk Caps | **NOT STARTED** | none |
| 10. Human Live Approval | **NOT STARTED** | none |

Gate 5 is the only one that can be assessed without running the EA: it is a
static property of the source tree and is re-checked by
`scripts/static_safety_scan.py` (see [Phase 7 tooling](#tooling-map)).

## Sequence

Gates are ordered and mostly sequential. A blocking gate must pass before the
next is attempted:

```
1 Compile ──► 2 Signal-Only ──► 3 Strategy Tester ──► 4 Risk Traceability
   (blocking)    (blocking)         (blocking)            (blocking)
                                                              │
   5 Strategy/Execution separation (continuous, static) ◄─────┘
                                                              │
6 Multi-Symbol/TF ──► 7 Performance Review ──► 8 Demo Forward Test
   (advisory→blocking)   (advisory)               (blocking)
        │
        ▼
9 Live Risk Caps (blocking) ──► 10 Human Live Approval (blocking, manual)
```

## Tooling map

Each gate has a doc and, where automatable from exported evidence, a read-only
helper script:

| Gate | Doc | Helper script |
|---|---|---|
| 1 | [COMPILE_VERIFICATION.md](COMPILE_VERIFICATION.md) | `scripts/parse_metaeditor_compile_log.py` |
| 2–3 | [STRATEGY_TESTER_VALIDATION.md](STRATEGY_TESTER_VALIDATION.md), [SIGNAL_ONLY_TEST.md](SIGNAL_ONLY_TEST.md), [BACKTEST_OUTPUTS.md](BACKTEST_OUTPUTS.md) | `scripts/validate_cls_backtest_package.py` |
| 4 | [RISK_BOUNDARY_AUDIT.md](RISK_BOUNDARY_AUDIT.md) | `scripts/audit_cls_risk_boundary.py` |
| 5 | [EA_ARCHITECTURE_REVIEW.md](EA_ARCHITECTURE_REVIEW.md) | `scripts/static_safety_scan.py` |
| 7 | [PERFORMANCE_REVIEW.md](PERFORMANCE_REVIEW.md) | `scripts/review_cls_performance.py` |
| 8 | [DEMO_READINESS.md](DEMO_READINESS.md) | `scripts/review_cls_performance.py` |
| 9–10 | [REAL_ACCOUNT_READINESS_GATE.md](REAL_ACCOUNT_READINESS_GATE.md) | manual / human approval |

All helper scripts are read-only: they read text/CSV/HTML evidence and write
markdown + JSON reports. None of them control MT5/MetaEditor, connect to a
broker, send orders, toggle AutoTrade, or change EA parameters. See
[AGENT_COMPANION_BOUNDARY.md](AGENT_COMPANION_BOUNDARY.md).

## How to advance a gate

1. Produce the gate's required evidence on a real MT5 install (compile log,
   exported backtest package, demo logs).
2. Run the corresponding helper script against that evidence.
3. Attach the script's `.md` / `.json` output as the gate's record.
4. A human reviews and decides whether the gate passes.

No gate advances automatically and no script self-approves a gate.
