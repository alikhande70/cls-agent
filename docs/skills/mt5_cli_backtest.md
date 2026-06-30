---
name: mt5-cli-backtest
description: Compiling and backtesting an MT5/MQL5 EA from the Windows command line. Use whenever building CLSAgent.mq5 or running the Strategy Tester headlessly.
---

# MT5 command-line build & backtest — hard rules

## Compile (Gate 1)
- Run: metaeditor64.exe /compile:"<DataFolder>\MQL5\Experts\CLSAgent\CLSAgent.mq5" /log
- It writes a log file next to the .mq5. Convert it to plain text as compile_log.txt
  (keep every per-line diagnostic AND the trailing "N errors, M warnings" line —
  the repo parser needs both).
- 0 errors required. Warnings must be listed, not ignored.

## tester.ini — three silent-failure traps
1. Save the .ini as ASCII. UTF-8-with-BOM makes MT5 ignore the WHOLE file with no error.
2. Always launch with /portable. Without it MT5 ignores the [Tester] section silently.
3. Set EA inputs in a [TesterInputs] section — Symbol/Period in [Tester] is not enough.

## Run a backtest
- terminal64.exe /portable /config:"<full path>\tester.ini"
- The terminal runs in the background and self-closes (ShutdownTerminal=1).
- DO NOT wait on a window. Poll for the report file existing AND size > 0, with a timeout
  (e.g. 30 min). If timeout, capture the terminal/tester logs and STOP.

## Reproducibility
Record Symbol, Period, Model, FromDate, ToDate, spread, Deposit for EVERY run so
Baseline and later runs are comparable. Mismatched settings invalidate the comparison.
