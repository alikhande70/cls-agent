# Code Review Workflow

This document defines how **external review tooling** — any reviewer, contributor,
or GitHub MCP-compatible review tool — may work with this repository. It is bound
by [AGENT_COMPANION_BOUNDARY.md](AGENT_COMPANION_BOUNDARY.md).

## What a reviewer / review tool MAY do

- **Read and explain** the source code and docs.
- **Review architecture** and confirm module boundaries (see
  [EA_ARCHITECTURE_REVIEW.md](EA_ARCHITECTURE_REVIEW.md)).
- **Diagnose compile issues** from a provided `compile_log.txt` (it does not run
  the compiler itself) and report them.
- **Propose patches** as diffs / pull requests for human review.
- **Update documentation.**
- **Add tests and read-only helper scripts** (like those in `scripts/`).
- **Prepare validation reports** by running the read-only helpers against
  evidence the operator exported.

## What a reviewer / review tool MUST NOT do

- enable live trading;
- send, modify, or close orders;
- bypass the Risk Engine;
- modify live risk settings without an explicit owner request;
- store credentials / sessions / cookies / API keys;
- activate AutoTrade or set `Mode = AUTO_TRADE`.

If a real compile issue is found, it is **reported first** (e.g. via the
[Compile Error Report](../.github/ISSUE_TEMPLATE/compile-error-report.md)
template) before any source change is proposed. All readiness-layer changes are
additive and must not weaken the Strategy / Risk / Execution boundaries — the
`scripts/static_safety_scan.py` check exists to catch regressions.

## Typical review loop

1. **Understand** — read the EA modules and the readiness docs.
2. **Static safety** — run `python3 scripts/static_safety_scan.py` to confirm
   the boundaries still hold (no broker run needed).
3. **Compile (operator-run)** — the operator compiles in MetaEditor and shares
   `compile_log.txt`, which is parsed with
   `scripts/parse_metaeditor_compile_log.py`.
4. **Validate (operator-run)** — the operator exports a test package, which is
   checked with `validate_cls_backtest_package.py`, `audit_cls_risk_boundary.py`,
   and `review_cls_performance.py`.
5. **Report** — results are summarized against the
   [readiness gates](REAL_ACCOUNT_READINESS_GATE.md) with proposed next steps.
6. **Propose** — any code change goes out as a PR for human review; nothing is
   auto-merged to `main` unless operated directly by the owner/admin.

## Boundary, restated

External review tooling is a reviewer and report generator. It never becomes an
execution controller, order sender, risk override, or auto-trading operator. The
deterministic EA, after gates and human approval, is the only thing that trades.
