# Changelog

All notable changes to CLS Agent are documented in this file.

## [Unreleased] — Documentation generalization (MT5 install/runbook)

Docs-only cleanup. **No MQL5, script, or trading-behavior changes.**

- Replaced the assistant-branded operational runbook with a neutral
  `docs/MT5_INSTALL_COMPILE_BACKTEST_RUNBOOK.md` (adds a dependency preflight and
  install-missing-dependencies section).
- Renamed the review-workflow doc to `docs/CODE_REVIEW_WORKFLOW.md` and removed
  the redundant local-validation doc (its content is covered by the runbook).
- Neutralized assistant-specific branding in `README.md`, `ROADMAP.md`,
  `LICENSE`, and `docs/CLS_COMPANION_MCP_ROADMAP.md`.
- Preserved the EA's LLM / MCP / Companion safety architecture and the
  `CLS_LLM_CAN_SEND_ORDERS` constant unchanged. Baseline remains the default;
  QuickProfitMode remains not fully implemented; real trading remains not
  approved. All performance remains PENDING BACKTEST / PENDING DEMO VALIDATION.

## [Unreleased] — EA Readiness + Companion Review Layer

Additive readiness layer around the existing deterministic EA. **No EA trading
logic, structure, or order behavior was changed.**

- Added `docs/` readiness documentation:
  - `EA_ARCHITECTURE_REVIEW.md`, `AGENT_COMPANION_BOUNDARY.md`,
    `READINESS_ROADMAP.md`.
  - `REAL_ACCOUNT_READINESS_GATE.md` — 10 gates from Compile Verification to
    Human Live Approval.
  - `COMPILE_VERIFICATION.md`, `STRATEGY_TESTER_VALIDATION.md`,
    `SIGNAL_ONLY_TEST.md`, `BACKTEST_OUTPUTS.md`, `RISK_BOUNDARY_AUDIT.md`,
    `PERFORMANCE_REVIEW.md`, `DEMO_READINESS.md`.
  - `CLS_COMPANION_MCP_ROADMAP.md` (documentation only — no MCP server),
    `CODE_REVIEW_WORKFLOW.md`, and a local validation workflow (later merged into
    `MT5_INSTALL_COMPILE_BACKTEST_RUNBOOK.md`).
- Added read-only `scripts/` helpers (Python 3, standard library only):
  `parse_metaeditor_compile_log.py`, `validate_cls_backtest_package.py`,
  `audit_cls_risk_boundary.py`, `review_cls_performance.py`,
  `static_safety_scan.py`, plus `README_COMPILE_HELPERS.md`. None control MT5,
  connect to a broker, send orders, enable AutoTrade, change EA parameters, or
  handle credentials.
- Added README "EA roadmap to live trading" and "Readiness layer & helper
  scripts" sections; cross-linked ROADMAP and TESTING to the gate model.
- Static safety scan confirms all `OrderSend()` / `CLS_SendMarketOrder()` call
  sites remain only in the Execution layer.

## [v0.1.0-beta] — Public beta preparation

- CLS Agent core architecture complete: Core, Market, Strategy, Risk,
  Execution, Memory, and Reporting modules implemented end-to-end.
- Setup detection (A–E), the Score Engine, loss-streak protection, and
  partial-fill/slippage handling added.
- Repository prepared for public, source-available release:
  - Added [README.md](README.md), [LICENSE](LICENSE),
    [DISCLAIMER.md](DISCLAIMER.md), and [CONTRIBUTING.md](CONTRIBUTING.md).
  - Added [ROADMAP.md](ROADMAP.md) and [TESTING.md](TESTING.md).
  - Added GitHub Issue templates: Compile Error Report, Backtest Result,
    Bug Report, Strategy Suggestion.
- MetaEditor compile verification: **pending** — not yet confirmed clean
  on a real MetaTrader 5 installation.
- Strategy Tester backtest validation: **pending** — no backtest report
  has been published yet for any symbol/timeframe.
