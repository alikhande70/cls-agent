# Claude Cowork — MetaTrader 5 Runbook

The complete, step-by-step local workflow for **Claude Cowork on Windows** to
clone this repository, compile the EA in MetaEditor, run validation/backtests,
collect artifacts, and report results back for review.

> **Read this first.** This runbook is operational guidance only. It does **not**
> authorize trading. Real trading is **not approved** and can only be considered
> after backtest evidence, a risk-boundary audit, demo forward testing, a
> live-readiness review, and **explicit human approval**.
>
> **Backtest success alone is not enough for real trading. Real trading requires
> backtest evidence, risk-boundary audit, demo forward testing, live-readiness
> review, and explicit human approval.**
>
> No profitability is claimed. All performance is **PENDING BACKTEST / PENDING
> DEMO VALIDATION**.

---

## 1. Purpose of the runbook
Give Cowork (or any human operator) a precise, safe procedure to: install the EA
into MetaTrader 5, **compile** it (Gate 1), run a **Signal-Only** validation
(Gate 2), run **Baseline** backtests (and later QuickProfitMode backtests),
collect the exported artifacts, run the repository's read-only validation
scripts, and return evidence for review. It never involves live trading.

## 2. Current project status
- `main` contains the **Baseline/Classic** deterministic EA **plus P1
  StrategyProfile infrastructure** (`InpStrategyProfile`, inert QuickProfit
  inputs, and a resolver).
- **QuickProfitMode is not fully implemented yet** — the QuickProfit inputs are
  inert and change no trading behavior. Baseline remains the default.
- **MetaEditor compile (Gate 1): not yet performed** on this codebase — it is
  the immediate next step this runbook drives.
- Demo and live: **not started / not approved.**

## 3. Required Windows / MT5 / MetaEditor environment
- Windows 10/11 with **MetaTrader 5** installed (includes **MetaEditor**).
- **Git for Windows** (provides Git Bash) and/or PowerShell.
- **Python 3** on PATH (for the read-only validation scripts). Check with
  `py -3 --version` or `python --version`.
- A broker account is **not** required for compile or for Strategy Tester runs on
  historical data. Do **not** use a live account anywhere in this runbook.

## 4. How to clone the repository (PowerShell)
```powershell
git clone https://github.com/alikhande70/cls-agent.git
cd cls-agent
```

## 5. How to checkout `main`
```powershell
git checkout main
git pull origin main
```

## 6. How to verify the expected commit
```powershell
git rev-parse HEAD
```
Record this SHA — it is the "commit under test" and must be passed to the compile
parser via `--commit`. (At the time this runbook was written, `main` was at
`351dad6856d464b47cab55390b855893211b9290`; always use the actual current value
returned above.)

## 7. How to locate the MetaTrader 5 Data Folder
In MetaTrader 5: **File → Open Data Folder**. This opens the terminal's data
folder, which contains the `MQL5\` tree (`MQL5\Experts\`, `MQL5\Include\`,
`MQL5\Files\`).

## 8. Which folders/files must be copied into the MT5 Data Folder
Copy from the cloned repo into the MT5 Data Folder, **preserving structure**:
- `MQL5\Experts\CLSAgent\CLSAgent.mq5`  →  `<DataFolder>\MQL5\Experts\CLSAgent\`
- `MQL5\Include\CLSAgent\`  (entire tree: Core, Market, Strategy, Risk,
  Execution, Memory, Reporting)  →  `<DataFolder>\MQL5\Include\CLSAgent\`
- `MQL5\Files\CLSAgent\`  (logs/reports/state folders)  →
  `<DataFolder>\MQL5\Files\CLSAgent\`

Copy the **entire** `Include\CLSAgent\` tree — a partial copy causes
missing-include errors.

## 9. How to compile `CLSAgent.mq5` in MetaEditor (Gate 1)
1. Open MetaEditor (MT5 → **Tools → MetaQuotes Language Editor**, or `F4`).
2. Open `MQL5\Experts\CLSAgent\CLSAgent.mq5`.
3. Press **F7** (Compile).
4. Open the **Toolbox → Errors** tab. Target: **0 errors**. Note any warnings.

## 10. How to capture `compile_log.txt`
Copy the **full** contents of the Errors tab into a plain-text file named
`compile_log.txt` in the **repo root**. Include the per-line diagnostics and the
trailing `N errors, M warnings` summary. A screenshot of the Errors tab is a
useful secondary artifact.

## 11. How to run `scripts/parse_metaeditor_compile_log.py`
From the repo root (PowerShell):
```powershell
py -3 .\scripts\parse_metaeditor_compile_log.py .\compile_log.txt --out .\compile_summary.md --json-out .\compile_summary.json --commit <CURRENT_MAIN_SHA>
```
If `py -3` is unavailable:
```powershell
python .\scripts\parse_metaeditor_compile_log.py .\compile_log.txt --out .\compile_summary.md --json-out .\compile_summary.json --commit <CURRENT_MAIN_SHA>
```
Git Bash equivalents:
```bash
python3 scripts/parse_metaeditor_compile_log.py compile_log.txt --out compile_summary.md --json-out compile_summary.json --commit <CURRENT_MAIN_SHA>
# or, if python3 is unavailable:
python scripts/parse_metaeditor_compile_log.py compile_log.txt --out compile_summary.md --json-out compile_summary.json --commit <CURRENT_MAIN_SHA>
```
Supported flags only: `--out`, `--json-out`, `--commit`, `--timestamp` (plus the
positional log path). Do not pass other flags.

## 12. Gate 1 pass/fail criteria
- **PASS:** parser exit code `0`; `compile_summary.json` `status: PASS`;
  `total_errors: 0`. Warnings are reviewed but not automatically blocking.
- **FAIL (blocking):** parser exit code `1`; `status: FAIL`; one or more errors.

## 13. What to do if compile fails
- **Do not** edit, patch, or "quick-fix" anything under `MQL5/`.
- **Do not** comment out code or bypass any module.
- **Do not** proceed to Signal-Only, backtest, demo, or live.
- **Do** return `compile_log.txt`, `compile_summary.md`, and
  `compile_summary.json` so the errors can be reviewed and a fix proposed for
  **owner approval** (e.g. via the Compile Error Report issue template).

## 14. How to run Signal-Only validation (Gate 2)
With Gate 1 PASS:
1. MT5 → **View → Strategy Tester** (`Ctrl+R`).
2. **Expert Advisor:** `CLSAgent`. **Symbol:** `XAUUSD` (or broker suffix).
   **Timeframe:** `M5` or `M15`. **Model:** "Every tick based on real ticks".
3. In the EA inputs, keep the safe defaults:
   - `InpStrategyProfile = CLS_PROFILE_BASELINE`
   - `InpMode = CLS_MODE_SIGNAL_ONLY`
   - `InpAutoTrade = false`
4. Run to completion. SIGNAL_ONLY must produce a populated decision journal and
   **no trades**.

## 15. How to export / copy output files
The EA writes under `<DataFolder>\MQL5\Files\CLSAgent\`:
- `logs\journal.csv`, `logs\trades.csv`, `logs\baskets.csv`
- `reports\performance.csv`, `reports\backtest_summary.txt`

Also save the Strategy Tester's own report (**Strategy Tester → Report tab →
right-click → Save as Report**, `.htm`/`.html`). Copy all of these into a package
directory for validation (see §20).

> Output-path note: `journal.csv`, `trades.csv`, and `baskets.csv` are written to
> `logs\`; `performance.csv` and `backtest_summary.txt` to `reports\`. The
> validation scripts locate files **recursively by name**, so a flattened
> package directory also works.

## 16. How to validate Signal-Only output
```powershell
py -3 .\scripts\validate_cls_backtest_package.py <PACKAGE_DIR> --mode SIGNAL_ONLY --out validation.md --json-out validation.json
```
PASS requires the journal populated and `trades.csv` empty/absent. Supported
flags only: `--mode {SIGNAL_ONLY,AUTO_TRADE}`, `--out`, `--json-out` (plus the
positional package dir).

## 17. How to run a Baseline backtest
1. Strategy Tester with `InpStrategyProfile = CLS_PROFILE_BASELINE`.
2. For execution inside the tester, set `InpMode = CLS_MODE_AUTO_TRADE` and
   `InpAutoTrade = true` **in the tester only** (this is historical simulation,
   never a live/real account).
3. Choose symbol, timeframe, date range, spread model, and deposit; **record
   them** so the QuickProfit run can match exactly.
4. Run to completion and collect outputs into a **Baseline** package directory.

## 18. How to run a QuickProfitMode backtest later (after implementation)
QuickProfitMode is **not implemented yet** — do this only after the later,
owner-approved phases (P2+) land and compile clean. When available:
1. Use the **same** symbol, timeframe, date range, spread model, deposit, and
   risk inputs as the Baseline run.
2. Set `InpStrategyProfile = CLS_PROFILE_QUICK_PROFIT` (and any QuickProfit
   inputs as directed by that phase's instructions).
3. Run to completion and collect outputs into a **separate** QuickProfit package
   directory.

## 19. How to keep Baseline and QuickProfitMode results separated
Use distinct package directories per profile and per run, e.g.:
```
artifacts\baseline\XAUUSD_M5_2023-2024\
artifacts\quickprofit\XAUUSD_M5_2023-2024\
```
Never overwrite Baseline evidence with QuickProfit evidence — the comparison
depends on both being preserved. (When P4 adds a `strategyProfile` tag to the
CSVs, rows will also self-identify; until then, directory separation is the
source of truth.)

## 20. Required output package structure
Each package directory should contain:
```
<package>/
  journal.csv
  trades.csv
  baskets.csv
  performance.csv
  backtest_summary.txt
  <StrategyTesterReport>.htm   (or .html)
  compile_log.txt              (for the Gate 1 run; optional in later packages)
  compile_summary.md / .json   (Gate 1 evidence)
```
A flattened layout is fine; the scripts search recursively by file name.

## 21. How to run validation scripts
From the repo root, against a package directory:
```powershell
py -3 .\scripts\validate_cls_backtest_package.py <PACKAGE_DIR> --mode SIGNAL_ONLY --out validation.md --json-out validation.json
# for an execution-enabled tester run:
py -3 .\scripts\validate_cls_backtest_package.py <PACKAGE_DIR> --mode AUTO_TRADE --out validation.md --json-out validation.json
```
You can also re-run the source boundary check at any time (no broker needed):
```powershell
py -3 .\scripts\static_safety_scan.py --root MQL5 --out safety_scan.md --json-out safety_scan.json
```
Supported flags only — `static_safety_scan.py`: `--root`, `--out`, `--json-out`.

## 22. How to run the risk-boundary audit
```powershell
py -3 .\scripts\audit_cls_risk_boundary.py <PACKAGE_DIR> --max-orders-per-basket 2 --source-root MQL5 --out risk_boundary_audit.md --json-out risk_boundary_audit.json
```
Use the **same** `--max-orders-per-basket` the run was configured with (Baseline
default `2`). Optional flags: `--max-basket-risk-percent`, `--source-root`,
`--out`, `--json-out`. No other flags.

## 23. How to run the performance review
```powershell
py -3 .\scripts\review_cls_performance.py <PACKAGE_DIR> --out performance_review.md --json-out performance_review.json
```
Optional flags: `--min-sample`, `--min-profit-factor`, `--max-concentration`,
`--max-drawdown`, `--out`, `--json-out`. Verdict is an **engineering readiness**
verdict (`PASS_TO_DEMO` / `NEEDS_REVIEW` / `REJECT_FOR_NOW` / `INCONCLUSIVE`),
**not** financial advice.

## 24. What artifacts to return for review
- `compile_log.txt`, `compile_summary.md`, `compile_summary.json` (Gate 1)
- the package CSVs + `backtest_summary.txt` + the Strategy Tester `.htm`/`.html`
- `validation.md` / `.json`
- `risk_boundary_audit.md` / `.json`
- `performance_review.md` / `.json`
- `safety_scan.md` / `.json`
- the exact run config (symbol, timeframe, date range, spread model, deposit,
  risk inputs, profile)

## 25. Safety boundaries
- `main` currently includes Baseline **and** P1 StrategyProfile infrastructure.
- QuickProfitMode is **not fully implemented**; Baseline remains the **default**.
- `InpMode` must remain `CLS_MODE_SIGNAL_ONLY` for signal-only validation.
- `InpAutoTrade` must remain `false` unless the **owner explicitly approves** a
  later gated test (and even then, only inside the Strategy Tester or a demo
  account, never a live/real account in this runbook).
- Live trading is **not approved**. No profitability is claimed. All performance
  is **PENDING BACKTEST / PENDING DEMO VALIDATION**.

## 26. What Claude Cowork must never do
- **Never** enable AutoTrade by itself.
- **Never** attach the EA to a live/real account for trading.
- **Never** send, modify, or close orders.
- **Never** bypass the Risk Engine.
- **Never** change live-risk settings without explicit owner approval.
- **Never** edit/patch `MQL5/` to force a clean compile, or comment out / bypass
  modules.
- **Never** handle credentials, sessions, cookies, or API keys.
- **Never** claim profitability or live-readiness.

## 27. Full roadmap — GitHub implementation → backtest → demo → live-readiness
1. **GitHub-first implementation** (done / in progress): Baseline + P1 profile
   infrastructure on `main`; future phases (P2 profit-lock, P3 frequency guards,
   P4 logging, P5 A/B) land as separate, owner-approved PRs.
2. **Gate 1 — Compile Verification** (this runbook).
3. **Gate 2 — Signal-Only Test.**
4. **Gate 3 — Strategy Tester Validation** (+ Gate 6 multi-symbol/timeframe).
5. **Gate 4 — Risk Engine Traceability** (risk-boundary audit on evidence).
6. **Gate 7 — Performance Review** (engineering verdict).
7. **Gate 8 — Demo Forward Testing** (demo account, owner-enabled).
8. **Gate 9 — Live Risk Caps** and **Gate 10 — Human Live Approval** (manual).

See [REAL_ACCOUNT_READINESS_GATE.md](REAL_ACCOUNT_READINESS_GATE.md) for the full
gate definitions and [READINESS_ROADMAP.md](READINESS_ROADMAP.md) for status.

## 28. Next phases after Gate 1
- If Gate 1 **PASS**: run Gate 2 (Signal-Only) on Baseline; collect + validate;
  then a Baseline Strategy Tester run (Gate 3) + risk audit (Gate 4) +
  performance review (Gate 7).
- If Gate 1 **FAIL**: return the compile evidence; a fix is proposed for owner
  approval before anything else proceeds.
- QuickProfitMode (P2+) is implemented **only** after owner approval, then A/B
  backtested against Baseline under identical conditions (see
  [QUICKPROFIT_MODE_DESIGN.md](QUICKPROFIT_MODE_DESIGN.md)).

---

_Related docs:_ [COMPILE_VERIFICATION.md](COMPILE_VERIFICATION.md),
[SIGNAL_ONLY_TEST.md](SIGNAL_ONLY_TEST.md),
[STRATEGY_TESTER_VALIDATION.md](STRATEGY_TESTER_VALIDATION.md),
[BACKTEST_OUTPUTS.md](BACKTEST_OUTPUTS.md),
[RISK_BOUNDARY_AUDIT.md](RISK_BOUNDARY_AUDIT.md),
[PERFORMANCE_REVIEW.md](PERFORMANCE_REVIEW.md),
[DEMO_READINESS.md](DEMO_READINESS.md),
[CLAUDE_COWORK_LOCAL_VALIDATION.md](CLAUDE_COWORK_LOCAL_VALIDATION.md),
[AGENT_COMPANION_BOUNDARY.md](AGENT_COMPANION_BOUNDARY.md).
