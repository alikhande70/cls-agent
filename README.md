# CLS Agent

**Full name:** Contextual Liquidity Scalping Agent
**Repository:** [`alikhande70/cls-agent`](https://github.com/alikhande70/cls-agent)
**Platform:** MetaTrader 5 / MQL5
**Status:** Beta / testing stage — not verified on live accounts

CLS Agent is a modular MQL5 Expert Advisor (EA) for scalping Gold
(`XAUUSD` / `XAUUSDm` / `GOLD`) and the major Forex pairs (`EURUSD`,
`GBPUSD`, `USDJPY`) using a deterministic, rule-based Basket Burst
approach. All entry, scoring, risk, and basket-management decisions are
made by code inside the EA. An LLM may analyze, review, and report on the
EA's behavior, but it never sends an order — that boundary is enforced in
code, not just by convention.

- **Main EA file:** `MQL5/Experts/CLSAgent/CLSAgent.mq5`
- **Include path:** `MQL5/Include/CLSAgent/`
- **Module-by-module build log:** `MQL5/Experts/CLSAgent/README.md`

This repository is public so the project's source can be viewed,
downloaded, and evaluated by anyone. **This is not financial advice.**
Profitability is not guaranteed, and live trading is not recommended
until you have completed full testing. Always test first in the MT5
Strategy Tester or on a demo account before considering a live account.
See [DISCLAIMER.md](DISCLAIMER.md) for the full risk disclosure.

## Architecture overview

CLS Agent is split into independent modules under
`MQL5/Include/CLSAgent/`, each with a single responsibility. `OnTick()`
in `CLSAgent.mq5` is a thin orchestrator — it never contains trading
logic itself, it only calls into the pipeline stages below in order:

| Module | Path | Responsibility |
|---|---|---|
| Core | `Core/` | Shared types, constants, and EA lifecycle wiring |
| Market | `Market/` | Price/indicator context, session and news state |
| Strategy | `Strategy/` | Setup detection (A–E) and the Score Engine |
| Risk | `Risk/` | Position sizing, loss protection, basket risk limits, news/session gates |
| Execution | `Execution/` | Order sending, retries, slippage/partial-fill handling |
| Memory | `Memory/` | Adaptive state persisted across ticks/restarts |
| Reporting | `Reporting/` | Logging, CSV export, on-chart debug panel, backtest summary |

Two structural rules hold across every module and are enforced in code,
not just convention:

1. **The Strategy layer never sends orders.** Only the Execution layer
   (`CLS_ExecuteBasketOrder()` / `CLS_SendMarketOrder()`) may call
   `OrderSend()`.
2. **The Risk Engine is never bypassed.** Every order, from any setup,
   must be approved by `RiskEngine` before it reaches Execution.

See `MQL5/Experts/CLSAgent/README.md` for the full module-by-module build
log, and [CONTRIBUTING.md](CONTRIBUTING.md) for the complete list of
safety rules contributions must preserve.

## Current project status

- Core architecture (Core / Market / Strategy / Risk / Execution / Memory
  / Reporting) is implemented end-to-end.
- Setup detection (A–E), the Score Engine, loss-streak protection, and
  partial-fill/slippage handling are implemented.
- MetaEditor compile verification: **pending** — not yet confirmed clean
  on a real MetaTrader 5 installation.
- Strategy Tester backtest validation: **pending** — no backtest report
  has been published yet for any symbol/timeframe.
- Demo forward testing: **not started**.
- Live trading: **not recommended** — see [DISCLAIMER.md](DISCLAIMER.md).

See [ROADMAP.md](ROADMAP.md) for the planned path to a stable release,
and [CHANGELOG.md](CHANGELOG.md) for what changed in each version.

## Download

**Option A — Download ZIP from GitHub**
Go to the repository page → **Code** → **Download ZIP**.

**Option B — Clone with Git**
```bash
git clone https://github.com/alikhande70/cls-agent.git
```

**Option C — GitHub Releases**
Download a packaged version from the
[Releases](https://github.com/alikhande70/cls-agent/releases)
page once the first release is published.

## Installing into MetaTrader 5

1. Open MetaTrader 5.
2. Go to: **File → Open Data Folder**.
3. Copy `MQL5/Experts/CLSAgent/CLSAgent.mq5` into `MQL5/Experts/CLSAgent/`
   in your data folder.
4. Copy `MQL5/Include/CLSAgent/` into `MQL5/Include/CLSAgent/` in your
   data folder.
5. Open MetaEditor.
6. Compile `CLSAgent.mq5` (F7).
7. Run it first in the **Strategy Tester**.
8. Do not run it on a real account before full testing.

`Mode` defaults to `SIGNAL_ONLY` and `AutoTrade` defaults to `false`, so
attaching the EA cannot place any order until both are explicitly
switched on. See `MQL5/Experts/CLSAgent/README.md` for the full module
build log and architecture notes.

## Strategy Tester instructions

Always validate in the Strategy Tester before any demo or live use:

1. Open MetaTrader 5 → **View → Strategy Tester** (or `Ctrl+R`).
2. Select **Expert Advisor:** `CLSAgent`.
3. Select **Symbol:** `XAUUSD` (or your broker's `XAUUSDm` / `GOLD`
   suffix) and **Timeframe:** `M5` or `M15` for the first run.
4. Set **Model:** "Every tick based on real ticks" (or the most accurate
   model your broker's history supports) for realistic fill/slippage
   behavior.
5. In the EA's inputs, leave `Mode = SIGNAL_ONLY` and `AutoTrade = false`
   for the first run so you can review signal quality with zero order
   risk.
6. Run the test and review the generated logs/exports described in
   [TESTING.md](TESTING.md) (`journal.csv`, `trades.csv`, `baskets.csv`,
   `performance.csv`, `backtest_summary.txt`).
7. Only enable `AutoTrade = true` in the tester, and only move to a demo
   account, after a clean `SIGNAL_ONLY` run with no unexpected behavior.

Full pass/fail criteria and required outputs are documented in
[TESTING.md](TESTING.md).

## Using with MCP / Claude Code

This repository can be cloned locally and opened by Claude Code or any
GitHub MCP-compatible tool. AI tools may inspect the code, explain it,
and suggest improvements. AI tools must not auto-commit to `main` unless
operated directly by the repository owner/admin.

If you'd like to propose a change after AI-assisted review, please open
an Issue, start a Discussion, or submit a Pull Request — direct
modification of the original repository is not allowed without owner
approval.

## Contributing

Bug reports, compile-error reports, backtest results, and strategy
suggestions are welcome via Issues, Discussions, and Pull Requests. See
[CONTRIBUTING.md](CONTRIBUTING.md) for what's accepted and the
constraints code contributions must respect.

## License

This project uses a **custom Source-Available License**, not MIT, GPL, or
Apache-2.0. Viewing, downloading, cloning, local/educational testing, and
submitting Issues/Discussions/Pull Requests are all permitted without
asking. Selling, rebranding, redistributing modified copies, or any
commercial use require written permission from the owner. See
[LICENSE](LICENSE) for the full terms.

## Disclaimer

This is experimental trading software, not financial advice. Trading
involves risk and no profit is guaranteed. See
[DISCLAIMER.md](DISCLAIMER.md).
