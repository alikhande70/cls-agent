# Compile Verification (Gate 1)

This is the workflow for **Gate 1 — Compile Verification** in
[REAL_ACCOUNT_READINESS_GATE.md](REAL_ACCOUNT_READINESS_GATE.md). It is the
first and most fundamental gate: nothing else proceeds until the EA compiles
cleanly.

## Goal

Produce evidence that `CLSAgent.mq5` compiles with **0 errors** on a real
MetaTrader 5 installation, and a parsed summary of any warnings.

## Step 1 — Compile in MetaEditor

1. Open MetaTrader 5 → **File → Open Data Folder**.
2. Confirm both of these are present under the data folder:
   - `MQL5/Experts/CLSAgent/CLSAgent.mq5`
   - the full `MQL5/Include/CLSAgent/` tree (Core, Market, Strategy, Risk,
     Execution, Memory, Reporting).
3. Open MetaEditor (**Tools → MetaQuotes Language Editor**, or `F4`).
4. Open `CLSAgent.mq5` and press **F7** (Compile).
5. Open the **Toolbox → Errors** tab.

## Step 2 — Capture the compile log

Copy the full contents of the Errors tab into a plain text file, e.g.
`compile_log.txt`. Include the per-line diagnostics and the trailing
`N errors, M warnings` summary line. A screenshot of the Errors tab is a useful
extra artifact but the text log is what the parser reads.

The parser understands MetaEditor's standard diagnostic format:

```
CLSAgent_RiskEngine.mqh(123,45) : error 246: some message
CLSAgent_RiskEngine.mqh(50,9) : warning 43: some message
Result: 0 errors, 1 warnings, ...
```

## Step 3 — Parse the log

```bash
python3 scripts/parse_metaeditor_compile_log.py compile_log.txt \
    --out compile_summary.md \
    --json-out compile_summary.json \
    --commit "$(git rev-parse --short HEAD)" \
    --timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

The script:

- extracts every error and warning with file path + line (+ column / code when
  present);
- lists the files affected;
- records the optional `--commit` / `--timestamp` you pass in;
- writes a markdown summary and a JSON summary;
- **exits non-zero (1) if any error exists** — Gate 1 is blocking.

## Step 4 — Record the result

Attach `compile_summary.md` and `compile_summary.json` (and optionally
`compile_log.txt` and the screenshot) as the Gate 1 evidence record. Update the
status table in [READINESS_ROADMAP.md](READINESS_ROADMAP.md).

## Acceptance / fail

- **Pass:** 0 errors. Warnings reviewed and documented.
- **Fail (blocking):** any compile error. If a real compile issue is found, it
  is **reported first** (e.g. via the
  [Compile Error Report](../.github/ISSUE_TEMPLATE/compile-error-report.md)
  issue template) before any source change is proposed — see the additive-only
  rule in [AGENT_COMPANION_BOUNDARY.md](AGENT_COMPANION_BOUNDARY.md).

## Safety note

`scripts/parse_metaeditor_compile_log.py` only reads the log text file you give
it and writes report files. It never controls MT5/MetaEditor, connects to a
broker, or touches EA parameters.
