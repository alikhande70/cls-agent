//+------------------------------------------------------------------+
//|                                    CLSAgent_DecisionEngine.mqh   |
//|   CLS Agent v2.4+ - Strategy / Decision Engine - Part 4          |
//|                                                                    |
//|   Turns a scored signal into an accept/reject verdict against the  |
//|   asset class's own threshold (Rule #8). This is purely a score    |
//|   gate - spread/session/ATR/daily-loss hard gates belong to the    |
//|   Risk Engine (Part 5), which runs after this regardless of the    |
//|   verdict here so Rule #9 (log every accepted AND rejected signal) |
//|   always has a complete SScoreResult to journal.                   |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_DECISIONENGINE_MQH
#define CLSAGENT_DECISIONENGINE_MQH

#include "../Core/CLSAgent_Types.mqh"
#include "../Market/CLSAgent_SymbolProfile.mqh"
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
