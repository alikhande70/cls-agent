---
name: Strategy Suggestion
about: Suggest a new setup, scoring factor, or risk/execution improvement
title: "[Suggestion] "
labels: suggestion
assignees: ''
---

## Summary

One or two sentences describing the idea.

## Which area does this affect?

- [ ] New setup / setup detection logic
- [ ] Score Engine (scoring factors, weighting)
- [ ] Risk Engine (sizing, loss protection, news/session gates)
- [ ] Execution (order sending, retries, slippage handling)
- [ ] Position Management (trailing, partial exit, breakeven)
- [ ] Memory / Reporting
- [ ] Other (describe below)

## Motivation

Why do you think this would help? Reference backtest evidence,
market behavior, or a specific gap you've noticed if you have it.

## Proposed approach

Describe how you'd implement this, at a high level. You don't need to
write code — a clear description is enough for a suggestion.

## Safety considerations

Confirm this suggestion does not:
- [ ] Move trading logic into `OnTick()`
- [ ] Let the Strategy layer send orders directly
- [ ] Bypass the Risk Engine
- [ ] Weaken any existing safety rule (Rule #1, #5, #6, etc.)
- [ ] Allow an LLM to send orders directly

## Additional context

Anything else relevant to evaluating this suggestion.
