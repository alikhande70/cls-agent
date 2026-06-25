//+------------------------------------------------------------------+
//|                                       CLSAgent_ScoreEngine.mqh   |
//|   CLS Agent v2.4+ - Strategy / Score Engine - Part 4             |
//|                                                                    |
//|   Multiplicative score: a signal's own trigger quality            |
//|   (rawStrength, 0..1, graded by the detector that fired) times    |
//|   continuous context multipliers for session, ATR regime and      |
//|   spread quality. Hard env gates (Rule #7's spread/session/ATR/   |
//|   daily-loss blocks) live in the Risk Engine (Part 5), not here -  |
//|   this stage only grades how good a signal is, never blocks it    |
//|   outright. Rule #8: the accept threshold is resolved per asset    |
//|   class via g_SymbolProfile.minScoreToTrade (Gold vs Forex).      |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_SCOREENGINE_MQH
#define CLSAGENT_SCOREENGINE_MQH

#include "../Core/CLSAgent_Constants.mqh"
#include "../Core/CLSAgent_Types.mqh"
#include "../Market/CLSAgent_SymbolProfile.mqh"

double CLS_SessionScoreFactor(const ENUM_CLS_SESSION session)
{
   switch(session)
   {
      case CLS_SESSION_OVERLAP: return 1.10; // London+NY overlap - best liquidity
      case CLS_SESSION_LONDON:  return 1.00;
      case CLS_SESSION_NEWYORK: return 1.00;
      case CLS_SESSION_ASIAN:   return 0.85; // thinner liquidity, more noise
      default:                  return 0.70; // CLS_SESSION_OFF
   }
}

double CLS_ATRRegimeScoreFactor(const ENUM_CLS_ATR_REGIME regime)
{
   // EXTREME is hard-blocked downstream in the Risk Engine (ctx.atrRegimeAllowed);
   // it is still scored low here for defense in depth, never relied on alone.
   switch(regime)
   {
      case CLS_ATR_REGIME_LOW:     return 0.90;
      case CLS_ATR_REGIME_NORMAL:  return 1.00;
      case CLS_ATR_REGIME_HIGH:    return 0.80; // penalized, not blocked - some setups still want it
      case CLS_ATR_REGIME_EXTREME: return 0.50;
      default:                     return 1.00;
   }
}

double CLS_SpreadScoreFactor(const double spreadPoints, const int maxSpreadPoints)
{
   if(maxSpreadPoints <= 0)
      return 1.0;

   const double ratio = spreadPoints / (double)maxSpreadPoints;
   if(ratio <= 0.5)
      return 1.05; // comfortably tight spread, small bonus
   if(ratio <= 1.0)
      return 1.05 - (ratio - 0.5) * 0.70; // glides 1.05 -> 0.70 as spread approaches the cap
   return 0.50; // already past the cap - Risk Engine will block it, but score it poorly too
}

//+------------------------------------------------------------------+
//| Combines the signal's own trigger quality with context quality    |
//| into a single 0..100 score. Returns 0 for an invalid signal.       |
//+------------------------------------------------------------------+
double CLS_ComputeScore(const SSetupContext &ctx, const SSetupSignal &signal)
{
   if(!signal.isValid)
      return CLS_SCORE_MIN;

   const double sessionFactor = CLS_SessionScoreFactor(ctx.session);
   const double atrFactor     = CLS_ATRRegimeScoreFactor(ctx.atrRegime);
   const double spreadFactor  = CLS_SpreadScoreFactor(ctx.spreadPoints, g_SymbolProfile.maxSpreadPoints);

   const double raw = CLS_SCORE_MAX * signal.rawStrength * sessionFactor * atrFactor * spreadFactor;
   return MathMax(CLS_SCORE_MIN, MathMin(CLS_SCORE_MAX, raw));
}

#endif // CLSAGENT_SCOREENGINE_MQH
