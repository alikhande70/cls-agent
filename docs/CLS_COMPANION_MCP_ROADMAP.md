# CLS Companion MCP — Roadmap & Interface (documentation only)

This document describes a **possible future** "CLS Companion" MCP server. **No
MCP server is implemented in this repository**, and this PR does not add MCP
runtime behavior. This is an interface contract and roadmap only — it exists so
that if such a tool is ever built, its boundaries are fixed in advance.

The governing rule is [AGENT_COMPANION_BOUNDARY.md](AGENT_COMPANION_BOUNDARY.md):
the Companion is a **review-and-report** tool. It never trades.

## Purpose

A CLS Companion MCP would let Claude Code / Claude Cowork run the same read-only
inspection and validation this repository already provides as scripts, through a
structured tool interface — inspecting source, parsing compile logs, validating
exported backtest packages, and generating readiness reports.

## What it reads

- the MQL5 source tree (`MQL5/Experts/CLSAgent/**`, `MQL5/Include/CLSAgent/**`);
- a MetaEditor compile log text file;
- exported test packages: `journal.csv`, `trades.csv`, `baskets.csv`,
  `performance.csv`, `backtest_summary.txt`, and the Strategy Tester
  `.htm`/`.html` report.

## What it produces

- compile summaries, backtest-package validations, risk-boundary audits,
  performance reviews, demo-readiness and live-readiness reports — all as
  markdown + JSON, mirroring the `scripts/` helpers.

## Allowed (future) capabilities

All read-only / report-only:

| Capability | Maps to |
|---|---|
| `cls_inspect_project_structure` | folder/module map review |
| `cls_inspect_inputs` | read `Core/CLSAgent_Inputs.mqh` |
| `cls_inspect_constants` | read `Core/CLSAgent_Constants.mqh` |
| `cls_inspect_risk_rules` | read `Risk/**` |
| `cls_inspect_execution_boundary` | confirm OrderSend lives only in `Execution/` |
| `cls_parse_compile_output` | `parse_metaeditor_compile_log.py` |
| `cls_validate_backtest_package` | `validate_cls_backtest_package.py` |
| `cls_import_journal_csv` | read `journal.csv` |
| `cls_import_trades_csv` | read `trades.csv` |
| `cls_import_baskets_csv` | read `baskets.csv` |
| `cls_import_performance_csv` | read `performance.csv` |
| `cls_generate_performance_report` | `review_cls_performance.py` |
| `cls_generate_risk_boundary_audit` | `audit_cls_risk_boundary.py` |
| `cls_generate_demo_readiness_report` | demo evidence review |
| `cls_generate_live_readiness_checklist` | gate checklist from evidence |

## Forbidden capabilities (must never exist)

- send order / modify order / close position
- enable AutoTrade
- activate live mode automatically
- change live risk settings without explicit human approval
- control the Execution layer
- bypass the Risk Engine
- store credentials / sessions / cookies / API keys
- auto-approve any gate

These are not "off by default" — they are out of scope for the Companion
entirely. The deterministic EA is the only thing that may ever place an order,
and only after the readiness gates and explicit human approval.

## Coordination with other MCP tools

If a CLS Companion is built alongside trading-capable MCP servers such as
`metatrader5-mcp` or an `mt5-trading-lab`, the division of responsibility is
strict:

- **CLS Companion** stays read-only: inspect, validate, report. It never calls
  any order/trade endpoint of another MCP server.
- **Any execution-capable MCP server** is driven only by an explicit human
  action, never chained automatically from a Companion report. A Companion
  report is an input to a human decision, not a trigger.
- No Companion output may be wired to auto-enable AutoTrade, auto-set
  `Mode = AUTO_TRADE`, or auto-change risk inputs on any account.

## Safe use from Claude Code / Claude Cowork

- Claude Code / Cowork may invoke the read-only capabilities to inspect code and
  generate readiness reports (see
  [CLAUDE_CODE_REVIEW_WORKFLOW.md](CLAUDE_CODE_REVIEW_WORKFLOW.md) and
  [CLAUDE_COWORK_LOCAL_VALIDATION.md](CLAUDE_COWORK_LOCAL_VALIDATION.md)).
- They must not use any tool — Companion or otherwise — to send orders, enable
  AutoTrade, or change live risk settings. Those remain manual human actions.
