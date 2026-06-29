# Backtest Outputs — file reference

This is the reference for the files a CLS Agent test run produces, and the exact
columns the validation tooling expects. These schemas are taken directly from
the EA's Memory and Reporting modules — they are facts about the current code,
not a proposal.

## Where the files land

On a real MetaTrader 5 install, under the terminal's data folder:

- `MQL5/Files/CLSAgent/logs/` — `journal.csv`, `trades.csv`, `baskets.csv`
  (the three append-only logs, all written through the shared
  `CLS_Csv_AppendLine()` helper, which targets `CLSAgent\logs\`)
- `MQL5/Files/CLSAgent/reports/` — `performance.csv`, `backtest_summary.txt`
  (the two point-in-time exports written by the Reporting module)

When you collect a package for validation you can keep that structure or
flatten it into one directory — `validate_cls_backtest_package.py` searches
recursively by file name, so it locates each file regardless of which
subfolder it lives in.

## File schemas

### `journal.csv` (append-only decision journal)

One row per signal that reached the Score Engine, **whether or not it was
executed** — the complete record of what the EA considered.

```
time,symbol,setup,direction,entry,sl,tp,score,scoreStatus,riskApproved,lots,rejectReason,executed,ticket
```

### `trades.csv` (append-only closed-trade log)

One row per closed deal (the closing side only), driven from
`OnTradeTransaction()`.

```
time,symbol,setup,magic,positionId,closeVolume,closePrice,profit
```

### `baskets.csv` (append-only basket composition log)

One row each time a direction's basket composition changes (open / grow /
shrink / flat).

```
time,symbol,direction,ordersCount,totalLots,averageEntry,isLosing,riskPercent
```

### `performance.csv` (point-in-time snapshot, overwritten)

Running totals overall (`ALL`) and per setup (A/B/C/D).

```
setup,trades,wins,losses,winRatePct,profitFactor,grossProfit,grossLoss
```

### `backtest_summary.txt` (human-readable summary)

Written from `OnTester()` at the end of a Strategy Tester pass: total trades,
wins/losses, win rate, profit factor, gross/net P/L, and a per-setup breakdown.

### Strategy Tester report (`.htm` / `.html`)

MetaTrader 5's own report (**Strategy Tester → Report tab → right-click → Save
as Report**). Recommended evidence for Gates 3 and 6.

## Relationship to the validator

`scripts/validate_cls_backtest_package.py` checks that these files exist, that
each CSV's required columns are present, that files are non-empty where
expected, that `performance.csv` parses, and — in `SIGNAL_ONLY` mode — that
`trades.csv` is empty or absent. See
[STRATEGY_TESTER_VALIDATION.md](STRATEGY_TESTER_VALIDATION.md).
