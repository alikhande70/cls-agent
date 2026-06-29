# Compile helpers — `scripts/`

This folder holds **read-only** Python helpers for the CLS Agent readiness
layer. They are plain Python 3 scripts (standard library only — no third-party
packages, no install step) that read evidence files and write report files.

## What these helpers DO

- Read text / CSV / HTML evidence you export from MetaTrader 5 / MetaEditor.
- Produce markdown (`.md`) and JSON (`.json`) reports for the readiness gates.
- Exit non-zero when a blocking condition is found, so they can be used in CI.

## What these helpers DO NOT do

By design, none of these scripts:

- control MetaTrader 5 or MetaEditor;
- send, modify, or close orders;
- enable AutoTrade or activate live mode;
- modify EA inputs/parameters or source files;
- connect to a broker or any network service;
- read, write, or store credentials / sessions / cookies / API keys.

This matches the boundary in
[../docs/AGENT_COMPANION_BOUNDARY.md](../docs/AGENT_COMPANION_BOUNDARY.md).

## The scripts

| Script | Gate | Reads | Writes |
|---|---|---|---|
| `parse_metaeditor_compile_log.py` | 1 | a MetaEditor compile log `.txt` | `compile_summary.md` / `.json` |
| `validate_cls_backtest_package.py` | 2–3, 6 | an exported package dir | `validation.md` / `.json` |
| `audit_cls_risk_boundary.py` | 4 | exported CSV logs (+ source) | `risk_boundary_audit.md` / `.json` |
| `review_cls_performance.py` | 7–8 | `performance.csv` (+ `trades.csv`) | report `.md` / `.json` |
| `static_safety_scan.py` | 5 | the `MQL5/` source tree | `safety_scan.md` / `.json` |

## Requirements

Python 3.8+ (standard library only). No `pip install` needed.

## Compile-log parser quick start

1. In MetaEditor, compile `CLSAgent.mq5` (F7).
2. Copy the compiler output (the **Toolbox → Errors** tab) into a text file,
   e.g. `compile_log.txt`.
3. Run:

   ```bash
   python3 scripts/parse_metaeditor_compile_log.py compile_log.txt \
       --out compile_summary.md --json-out compile_summary.json \
       --commit "$(git rev-parse --short HEAD)"
   ```

4. The script exits `0` if there are no errors, `1` if there are (blocking).

See [../docs/COMPILE_VERIFICATION.md](../docs/COMPILE_VERIFICATION.md) for the
full workflow.
