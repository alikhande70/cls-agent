# MetaTrader 5 Install, Compile, and Backtest Runbook

The official local workflow for installing, compiling, validating, and
backtesting the CLS Agent EA on Windows with MetaTrader 5. The operator may be a
human, a local workstation operator, a script runner, or any approved review
workflow — this guide assumes no specific assistant or vendor tool.

> **Read this first.** This runbook is operational guidance only. It does **not**
> authorize trading. Real trading is **not approved** and can only be considered
> after backtest evidence, a risk-boundary audit, demo forward testing, a
> live-readiness review, and **explicit human approval**.
>
> **Backtest success alone is not enough for real trading. Real trading requires
> compile pass, Signal-Only validation, backtest evidence, risk-boundary audit,
> demo forward testing, live-readiness review, and explicit human approval.**
>
> No profitability is claimed. All performance is **PENDING BACKTEST / PENDING
> DEMO VALIDATION**.

---

## 1. Purpose
Give the operator a precise, safe procedure to: verify dependencies, install the
EA into MetaTrader 5, **compile** it (Gate 1), run a **Signal-Only** validation
(Gate 2), run **Baseline** backtests, collect the exported artifacts, run the
repository's read-only validation scripts, and return evidence for review. It
never involves live trading.

## 2. Current project status
- `main` contains the **Baseline/Classic** deterministic EA **plus P1
  StrategyProfile infrastructure** (`InpStrategyProfile`, inert QuickProfit
  inputs, and a resolver).
- **QuickProfitMode is not fully implemented yet** — the QuickProfit inputs are
  inert and change no trading behavior. **Baseline remains the default.**
- **Gate 1 compile is pending local Windows / MT5 validation.**
- Backtest / demo / live evidence is **not yet available**.
- **Real trading is not approved.**

## 3. Dependency preflight checklist
Before installation or execution, verify every dependency is present:

- Windows 10/11
- MetaTrader 5 terminal
- MetaEditor (ships with MT5)
- Git for Windows
- Python 3
- PowerShell
- repository access
- historical market data for the Strategy Tester

Preflight commands (PowerShell or Git Bash):
```powershell
git --version
py -3 --version
python --version
```
- If **Git** is missing, install Git for Windows first.
- If **Python** is missing, install Python 3 and enable "Add Python to PATH".
- If **MetaTrader 5 / MetaEditor** is missing, install MT5 from your broker or
  the official MetaTrader source.
- If **MetaEditor** is not available, install or repair MT5 before continuing.
- **Do not** continue to compile/backtest until all dependencies are present.

## 4. Installing missing dependencies
Generic, vendor-neutral steps:
- **Git for Windows:** download the official Git for Windows installer, install
  with defaults; this also provides Git Bash. Verify with `git --version`.
- **Python 3:** download the official Python 3 installer; during setup tick
  **"Add Python to PATH"**. Verify with `py -3 --version` (or `python --version`).
- **MetaTrader 5 / MetaEditor:** install the MT5 terminal from your broker or the
  official MetaTrader distribution; MetaEditor is bundled. Launch MT5 once so the
  data folder is created.

## 5. Clone the repository (PowerShell)
```powershell
git clone https://github.com/alikhande70/cls-agent.git
cd cls-agent
git checkout main
git pull origin main
git rev-parse HEAD
```
The SHA returned by `git rev-parse HEAD` is the **commit under test**; record it
and pass it to the compile parser via `--commit`.

## 6. Locate the MT5 Data Folder
In MetaTrader 5: **File → Open Data Folder**. This opens the terminal's data
folder, which contains the `MQL5\` tree (`MQL5\Experts\`, `MQL5\Include\`,
`MQL5\Files\`).

## 7. Copy files into the MT5 Data Folder
Copy from the cloned repo into the MT5 Data Folder, **preserving structure**:
- `MQL5\Experts\CLSAgent\CLSAgent.mq5`  →  `<DataFolder>\MQL5\Experts\CLSAgent\`
- `MQL5\Include\CLSAgent\`  (entire tree: Core, Market, Strategy, Risk,
  Execution, Memory, Reporting)  →  `<DataFolder>\MQL5\Include\CLSAgent\`
- `MQL5\Files\CLSAgent\`  (logs/reports/state folders)  →
  `<DataFolder>\MQL5\Files\CLSAgent\`

Copy the **entire** `Include\CLSAgent\` tree — a partial copy causes
include/path errors.

## 8. Compile in MetaEditor (Gate 1)
1. Open MetaEditor (MT5 → **Tools → MetaQuotes Language Editor**, or `F4`).
2. Open `MQL5\Experts\CLSAgent\CLSAgent.mq5`.
3. Press **F7** (Compile).
4. Open the **Toolbox → Errors** tab. Target: **0 errors**. Warnings must be
   recorded and reviewed.

## 9. Capture compile evidence
Copy the **full** contents of the Errors tab into a plain-text file named
`compile_log.txt` in the repo root (include the per-line diagnostics and the
trailing `N errors, M warnings` summary). Then produce `compile_summary.md` and
`compile_summary.json`:
```powershell
py -3 .\scripts\parse_metaeditor_compile_log.py .\compile_log.txt --out .\compile_summary.md --json-out .\compile_summary.json --commit <CURRENT_MAIN_SHA>
```
If `py -3` is unavailable:
```powershell
python .\scripts\parse_metaeditor_compile_log.py .\compile_log.txt --out .\compile_summary.md --json-out .\compile_summary.json --commit <CURRENT_MAIN_SHA>
```
Git Bash equivalents use `python3` (or `python`) and forward slashes. Supported
flags only: `--out`, `--json-out`, `--commit`, `--timestamp` (plus the positional
log path).

## 10. Gate 1 pass/fail criteria
- **PASS:** 0 compile errors; parser status `PASS`; `blocking` false; exit code 0.
- **FAIL:** 1 or more compile errors; parser status `FAIL`; `blocking` true; exit
  code 1.

If **FAIL**:
- **Do not** edit `MQL5/` directly without review.
- **Do not** comment out modules or bypass errors.
- **Do not** proceed to Signal-Only or backtest.
- Collect `compile_log.txt` + `compile_summary.md/.json` and prepare a
  compile-error review for owner approval.

## 11. Signal-Only validation (Gate 2)
With Gate 1 PASS, run the Strategy Tester with the safe defaults:
- `InpStrategyProfile = CLS_PROFILE_BASELINE`
- `InpMode = CLS_MODE_SIGNAL_ONLY`
- `InpAutoTrade = false`

This is the first behavioral validation stage. It **must not place orders** — a
populated decision journal with no trades is the expected result.

## 12. Baseline backtest
1. Open the Strategy Tester (MT5 → **View → Strategy Tester**, `Ctrl+R`).
2. Expert Advisor `CLSAgent`; choose symbol (e.g. `XAUUSD`), timeframe (M5/M15),
   date range, spread model, and deposit; use "Every tick based on real ticks"
   where possible.
3. `InpStrategyProfile = CLS_PROFILE_BASELINE`. To simulate execution **inside
   the tester only**, set `InpMode = CLS_MODE_AUTO_TRADE` and
   `InpAutoTrade = true` (this is historical simulation, never a live/real
   account).
4. **Record** symbol/timeframe/date-range/spread/deposit so later runs match.
5. Run to completion and collect outputs into a Baseline package directory.

## 13. QuickProfitMode backtest (later, after implementation)
QuickProfitMode is **not fully implemented yet**. Only after the later,
owner-approved phases land and compile clean: run it with the **same** symbol,
timeframe, date range, spread model, deposit, and risk inputs as the Baseline
run, set `InpStrategyProfile = CLS_PROFILE_QUICK_PROFIT`, and collect outputs
into a **separate** package directory.

## 14. Keep Baseline and QuickProfitMode results separated
Use distinct, descriptive package directories per profile/run:
```
evidence/baseline/<symbol>/<timeframe>/<date-range>/
evidence/quickprofit/<symbol>/<timeframe>/<date-range>/
```
Never overwrite Baseline evidence with QuickProfit evidence — the comparison
depends on both being preserved.

## 15. Required output package
Expected artifacts per package:
```
compile_log.txt
compile_summary.md
compile_summary.json
journal.csv
trades.csv
baskets.csv
performance.csv
backtest_summary.txt
<StrategyTesterReport>.htm   (or .html)
validation_report.md / .json
risk_boundary_audit.md / .json
performance_review.md / .json
```
Current output locations written by the EA under `<DataFolder>\MQL5\Files\CLSAgent\`:
- `journal.csv`, `trades.csv`, `baskets.csv`  →  `MQL5/Files/CLSAgent/logs/`
- `performance.csv`, `backtest_summary.txt`  →  `MQL5/Files/CLSAgent/reports/`

A flattened package layout is fine — the validation scripts locate files
recursively by name.

## 16. Validation scripts
Run from the repo root against a package directory. Documented flags are the only
supported ones (verified via each script's `--help`).
```powershell
# Gate 1 — compile log
py -3 .\scripts\parse_metaeditor_compile_log.py .\compile_log.txt --out .\compile_summary.md --json-out .\compile_summary.json --commit <CURRENT_MAIN_SHA>

# Gates 2/3 — package validation (mode = SIGNAL_ONLY or AUTO_TRADE)
py -3 .\scripts\validate_cls_backtest_package.py <PACKAGE_DIR> --mode SIGNAL_ONLY --out validation_report.md --json-out validation_report.json

# Gate 5 — source boundary scan (no broker / no run needed)
py -3 .\scripts\static_safety_scan.py --root MQL5 --out safety_scan.md --json-out safety_scan.json

# Gate 4 — risk-boundary audit
py -3 .\scripts\audit_cls_risk_boundary.py <PACKAGE_DIR> --max-orders-per-basket 2 --source-root MQL5 --out risk_boundary_audit.md --json-out risk_boundary_audit.json

# Gate 7 — performance review
py -3 .\scripts\review_cls_performance.py <PACKAGE_DIR> --out performance_review.md --json-out performance_review.json
```
Supported flags by script:
- `parse_metaeditor_compile_log.py`: `--out`, `--json-out`, `--commit`, `--timestamp`
- `validate_cls_backtest_package.py`: `--mode {SIGNAL_ONLY,AUTO_TRADE}`, `--out`, `--json-out`
- `audit_cls_risk_boundary.py`: `--max-orders-per-basket`, `--max-basket-risk-percent`, `--source-root`, `--out`, `--json-out`
- `review_cls_performance.py`: `--min-sample`, `--min-profit-factor`, `--max-concentration`, `--max-drawdown`, `--out`, `--json-out`
- `static_safety_scan.py`: `--root`, `--out`, `--json-out`

## 17. Risk-boundary audit
`audit_cls_risk_boundary.py` validates, from exported evidence, that:
- every executed trade traces to an approved/executed journal row (no Risk Engine
  bypass);
- no basket exceeds the configured order/basket limits;
- no losing basket grew in order count (no-add-to-losing rule);
- (with `--source-root`) the Strategy layer contains no order-sending call.

Insufficient evidence yields **INCONCLUSIVE**, never a guessed pass.

## 18. Performance review
`review_cls_performance.py` produces an **engineering readiness** verdict
(`PASS_TO_DEMO` / `NEEDS_REVIEW` / `REJECT_FOR_NOW` / `INCONCLUSIVE`) from
exported metrics. **It is not financial advice** and makes no profitability
claim.

## 19. Demo forward testing
Demo forward testing follows **only** after compile pass + Signal-Only +
Baseline backtest + risk-boundary audit, and is run on a **demo** account with
the owner manually enabling execution. It is never run on a live/real account in
this runbook.

## 20. Live-readiness
**Backtest success alone is not enough for real trading.** Real trading requires
compile pass, Signal-Only validation, backtest evidence, risk-boundary audit,
demo forward testing, live-readiness review, and **explicit human approval**.

## 21. Forbidden actions
- Do **not** use a live/real account during installation or validation.
- Do **not** enable AutoTrade without explicit owner approval.
- Do **not** attach the EA to a live trading chart.
- Do **not** send/modify/close orders manually to make test output look correct.
- Do **not** bypass the Risk Engine.
- Do **not** alter live-risk settings without explicit owner approval.
- Do **not** ignore compile errors.
- Do **not** treat backtest success as live approval.

## 22. Final roadmap
```
GitHub implementation
  → local dependency check
  → install missing dependencies
  → clone repository
  → copy MQL5 files into the MT5 Data Folder
  → compile in MetaEditor
  → Gate 1 compile evidence
  → Signal-Only validation
  → Baseline backtest
  → risk-boundary audit
  → performance review
  → demo forward testing
  → live-readiness review
  → explicit human approval
  → possible real-account deployment
```
No shortcuts.

---

_Related docs:_ [COMPILE_VERIFICATION.md](COMPILE_VERIFICATION.md),
[SIGNAL_ONLY_TEST.md](SIGNAL_ONLY_TEST.md),
[STRATEGY_TESTER_VALIDATION.md](STRATEGY_TESTER_VALIDATION.md),
[BACKTEST_OUTPUTS.md](BACKTEST_OUTPUTS.md),
[RISK_BOUNDARY_AUDIT.md](RISK_BOUNDARY_AUDIT.md),
[PERFORMANCE_REVIEW.md](PERFORMANCE_REVIEW.md),
[DEMO_READINESS.md](DEMO_READINESS.md),
[REAL_ACCOUNT_READINESS_GATE.md](REAL_ACCOUNT_READINESS_GATE.md),
[CODE_REVIEW_WORKFLOW.md](CODE_REVIEW_WORKFLOW.md),
[AGENT_COMPANION_BOUNDARY.md](AGENT_COMPANION_BOUNDARY.md).
