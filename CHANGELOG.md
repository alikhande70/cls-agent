# Changelog

All notable changes to CLS Agent are documented in this file.

## [Unreleased]

- Daily Loss Limit breach now flattens all of this EA's open positions
  on the chart's symbol immediately (checked every tick), in addition
  to blocking new entries. Previously a breach only blocked new entries
  and left any already-open basket to run unmanaged for the rest of the
  broker day.
- NewsGuard now fails closed on a malformed manual news window (blocks
  entries) instead of silently skipping the malformed entry and failing
  open.
- Basket log now also writes a row when a partial exit shrinks a
  basket's total lots without changing its order count, not just when
  order count changes.
- Setup D (BMS Continuation)'s armed/pullback-waiting state is now
  persisted to disk and reloaded on EA restart, matching the existing
  `CLSAgent_PartialExit.mqh` restart-safety convention.
- Documentation consistency pass: corrected README/TESTING/ROADMAP
  references to a non-existent "Setup E" and to loss-streak-protection /
  partial-fill-handling claims that do not reflect this codebase;
  clarified that `Mode = SEMI_AUTO` is reserved, not implemented; added
  an explicit compile/backtest readiness checklist.

## [v0.1.0-beta] — Public beta preparation

- CLS Agent core architecture complete: Core, Market, Strategy, Risk,
  Execution, Memory, and Reporting modules implemented end-to-end.
- Setup detection (A–D) and the Score Engine added.
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
