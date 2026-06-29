# Claude Cowork — Local Validation Workflow (Windows)

This document defines how **Claude Cowork** may help validate CLS Agent on the
owner's **Windows** machine, where MetaTrader 5 and MetaEditor are installed. It
is bound by [AGENT_COMPANION_BOUNDARY.md](AGENT_COMPANION_BOUNDARY.md).

Every step that touches MT5/MetaEditor or an account requires **explicit user
approval**. Cowork assists; the human acts on anything that touches the
platform or an account.

## Safe, allowed workflow

1. **Copy the EA into the MT5 data folder** — *with user approval*.
   - `MQL5/Experts/CLSAgent/` → `<DataFolder>/MQL5/Experts/CLSAgent/`
   - `MQL5/Include/CLSAgent/` → `<DataFolder>/MQL5/Include/CLSAgent/`
   - `MQL5/Files/CLSAgent/` → `<DataFolder>/MQL5/Files/CLSAgent/`
2. **Compile in MetaEditor** — *with user approval*. The user presses F7; Cowork
   helps capture the compile log and parses it with
   `scripts/parse_metaeditor_compile_log.py` (Gate 1).
3. **Run a SIGNAL_ONLY test** — *with user approval*. `Mode = SIGNAL_ONLY`,
   `AutoTrade = false` (the defaults). Zero order risk (Gate 2).
4. **Collect exported outputs** from `MQL5/Files/CLSAgent/` into a package
   directory.
5. **Run the validation scripts** (all read-only):
   - `validate_cls_backtest_package.py --mode SIGNAL_ONLY` (Gate 2)
   - later, with execution enabled in the tester: `--mode AUTO_TRADE` (Gate 3)
   - `audit_cls_risk_boundary.py` (Gate 4)
   - `review_cls_performance.py` (Gate 7)
   - `static_safety_scan.py` (Gate 5)
6. **Generate readiness reports** and map them to the
   [readiness gates](REAL_ACCOUNT_READINESS_GATE.md).

## Cowork MUST NOT

- automatically enable AutoTrade;
- run the EA on a **real account** without explicit owner approval;
- store credentials / sessions / cookies / API keys;
- change risk settings without an explicit user request;
- bypass the Risk Engine;
- set `Mode = AUTO_TRADE` or activate live mode automatically.

## Notes

- The SIGNAL_ONLY pass is the cheapest safety check — always do it before
  enabling `AutoTrade` even in the tester.
- Demo forward testing (Gate 8) happens on a **demo** account, with the user
  manually enabling `AUTO_TRADE` — see [DEMO_READINESS.md](DEMO_READINESS.md).
- Live activation is **Gate 10**: explicit human approval only. No Cowork
  workflow may satisfy it.

Cowork is a local validation assistant. It prepares evidence and reports; the
human owns every action that touches the platform, an account, or trading.
