//+------------------------------------------------------------------+
//|                                    CLSAgent_DecisionEngine.mqh   |
//|   CLS Agent v2.4+ - Strategy / Decision Engine - Part 4, upgraded  |
//|   with an explicit veto layer in Phase 2                          |
//|                                                                    |
//|   Turns a scored signal into an accept/reject verdict. Score      |
//|   below the asset class's own threshold (Rule #8) is NO TRADE      |
//|   regardless of context; on top of that, an explicit veto layer    |
//|   can reject a HIGH-scoring signal outright - high spread, an       |
//|   active news/session block, or an extreme volatility spike. The     |
//|   Risk Engine (Part 5) still independently re-derives these exact     |
//|   same hard gates afterward regardless of this verdict (defense in     |
//|   depth, Rule #9: every accepted AND rejected signal still reaches      |
//|   the Journal with a complete SScoreResult) - this layer exists so      |
//|   the Decision Engine itself never waves through a signal it can         |
//|   already tell is unsafe, instead of leaving that solely to the           |
//|   downstream Risk stage.                                                   |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_DECISIONENGINE_MQH
#define CLSAGENT_DECISIONENGINE_MQH

#include "../Core/CLSAgent_Types.mqh"
#include "../Market/CLSAgent_SymbolProfile.mqh"
#include "../Risk/CLSAgent_NewsGuard.mqh"
#include "CLSAgent_ScoreEngine.mqh"

//+------------------------------------------------------------------+
//| Fills result and returns true iff the signal is accepted.         |
//+------------------------------------------------------------------+
bool CLS_DecideSignal(const SSetupContext &ctx, const SSetupSignal &signal, SScoreResult &result)
{
   result = SScoreResult(); // reset to safe defaults (REJECTED, score 0)

   if(!signal.isValid)
   {
      result.rejectReason = CLS_REJECT_OTHER;
      return false;
   }

   result.score = CLS_ComputeScore(ctx, signal);

   // Veto layer: each of these can reject the signal outright even if its
   // score cleared the threshold below.
   if(!ctx.spreadAllowed)
   {
      result.status       = CLS_SIGNAL_REJECTED;
      result.rejectReason = CLS_REJECT_SPREAD;
      return false;
   }
   if(!ctx.sessionAllowed)
   {
      result.status       = CLS_SIGNAL_REJECTED;
      result.rejectReason = CLS_REJECT_SESSION;
      return false;
   }
   if(CLS_IsInNewsWindow(TimeCurrent()))
   {
      result.status       = CLS_SIGNAL_REJECTED;
      result.rejectReason = CLS_REJECT_NEWS;
      return false;
   }
   if(!ctx.atrRegimeAllowed)
   {
      result.status       = CLS_SIGNAL_REJECTED;
      result.rejectReason = CLS_REJECT_ATR_REGIME;
      return false;
   }

   const double minScore = g_SymbolProfile.minScoreToTrade;
   if(result.score < minScore)
   {
      result.status       = CLS_SIGNAL_REJECTED;
      result.rejectReason  = CLS_REJECT_SCORE_LOW;
      return false;
   }

   result.status       = CLS_SIGNAL_ACCEPTED;
   result.rejectReason = CLS_REJECT_NONE;
   return true;
}

#endif // CLSAGENT_DECISIONENGINE_MQH
