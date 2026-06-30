---
name: cls-safety-boundary
description: Hard boundaries an AI/LLM must respect when working on the CLS Agent repo. Always in effect for this project.
---

# Non-negotiable boundaries (enforced in repo code as CLS_LLM_CAN_SEND_ORDERS=false)
- Review, run the tester, and report ONLY. Never send/modify/close an order.
- Never connect to a broker, never touch a live OR demo account, never handle credentials.
- Never enable AutoTrade outside the Strategy Tester.
- Never change live-risk settings.
- On compile failure: report exact errors. Never comment out modules, never bypass the
  Risk Engine, never edit MQL5/ to force a pass — collect evidence for owner review instead.
- Never auto-commit to main. Propose changes via Issue / Discussion / PR only.
- Two code invariants to verify, never break: Strategy layer never calls OrderSend (only
  Execution may); every order must pass RiskEngine first.
