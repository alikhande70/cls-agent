# Roadmap

This roadmap describes the planned path from public beta to a stable
release. Versions are only advanced once their stated criteria are met
— see [TESTING.md](TESTING.md) for how results are validated and
[CHANGELOG.md](CHANGELOG.md) for what has actually shipped.

## v0.1.0-beta — Public beta release (current)

- Repository cleanup and rename to `cls-agent`.
- Professional documentation: README, LICENSE, DISCLAIMER, CONTRIBUTING,
  CHANGELOG, ROADMAP, TESTING.
- Download and MCP/Claude Code readiness (clone, inspect, test locally).
- Daily Loss Limit hardening: a breach now flattens existing open
  positions immediately (every tick), not just new entries.

## v0.2.0 — Compile verified

- MetaEditor compile verified clean on a real MetaTrader 5 installation.
- Any compile errors found during verification fixed.
- First clean Strategy Tester run completed (no crashes, no unexpected
  orders in `SIGNAL_ONLY` mode).

## v0.3.0 — First backtest reports

- Published `XAUUSD` backtest report.
- Published `EURUSD` / `GBPUSD` / `USDJPY` backtest reports.
- Per-setup (A/B/C/D) performance review based on `performance.csv`.

## v0.4.0 — Demo forward testing

- Demo account forward testing over a meaningful sample of trades.
- Spread and slippage validation against live broker conditions.
- Broker execution-behavior review (requotes, partial fills, freeze
  level, etc.).

## v0.5.0 — Optimization and drawdown control

- Parameter optimization based on backtest and demo data.
- Walk-forward testing to check for overfitting.
- Drawdown control improvements based on observed worst-case behavior.

## v1.0.0 — Stable release candidate

- Promoted only after compile, backtest, and demo validation are all
  complete and documented. Not scheduled until v0.2.0–v0.5.0 criteria
  are met.
