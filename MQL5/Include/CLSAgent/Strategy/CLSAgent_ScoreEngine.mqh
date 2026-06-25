//+------------------------------------------------------------------+
//|                                       CLSAgent_ScoreEngine.mqh   |
//|   CLS Agent v2.4+ - Strategy / Score Engine - Part 4, upgraded   |
//|   to a weighted multi-factor model in Phase 2                    |
//|                                                                    |
//|   score = 100 * rawStrength * contextQuality, where rawStrength    |
//|   (0..1, graded by the detector that fired) gates the score on the |
//|   setup's own trigger quality, and contextQuality is a weighted     |
//|   average of six independent 0..1 quality reads: trend alignment,   |
//|   ATR volatility regime, session quality, spread condition,          |
//|   liquidity context and momentum confirmation. Hard env gates        |
//|   (Rule #7's spread/session/ATR/daily-loss blocks) live in the        |
//|   Risk Engine (Part 5), not here - this stage only grades how good     |
//|   a signal is, never blocks it outright. Rule #8: the accept            |
//|   threshold is resolved per asset class via                              |
//|   g_SymbolProfile.minScoreToTrade (Gold vs Forex).                        |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_SCOREENGINE_MQH
#define CLSAGENT_SCOREENGINE_MQH

#include "../Core/CLSAgent_Constants.mqh"
#include "../Core/CLSAgent_Types.mqh"
#include "../Core/CLSAgent_Inputs.mqh"
#include "../Market/CLSAgent_SymbolProfile.mqh"
#include "../Market/CLSAgent_LevelCache.mqh"

double CLS_SessionQuality(const ENUM_CLS_SESSION session)
{
   switch(session)
   {
      case CLS_SESSION_OVERLAP: return 1.00; // London+NY overlap - best liquidity
      case CLS_SESSION_LONDON:  return 0.85;
      case CLS_SESSION_NEWYORK: return 0.85;
      case CLS_SESSION_ASIAN:   return 0.60; // thinner liquidity, more noise
      default:                  return 0.30; // CLS_SESSION_OFF
   }
}

double CLS_ATRRegimeQuality(const ENUM_CLS_ATR_REGIME regime)
{
   // EXTREME is hard-blocked downstream in the Risk Engine (ctx.atrRegimeAllowed);
   // it is still scored low here for defense in depth, never relied on alone.
   switch(regime)
   {
      case CLS_ATR_REGIME_LOW:     return 0.75;
      case CLS_ATR_REGIME_NORMAL:  return 1.00;
      case CLS_ATR_REGIME_HIGH:    return 0.60; // penalized, not blocked - some setups still want it
      case CLS_ATR_REGIME_EXTREME: return 0.20;
      default:                     return 1.00;
   }
}

double CLS_SpreadQuality(const double spreadPoints, const int maxSpreadPoints)
{
   if(maxSpreadPoints <= 0)
      return 1.0;

   const double ratio = spreadPoints / (double)maxSpreadPoints;
   return MathMax(0.0, MathMin(1.0, 1.0 - ratio)); // linear falloff to 0 right at the cap
}

//+------------------------------------------------------------------+
//| Does the recent price drift actually support this signal's own     |
//| continuation/reversal claim? Continuation wants drift and          |
//| direction to agree; reversal wants the signal to fight the drift   |
//| (that is the whole premise of fading a liquidity sweep). Drift      |
//| magnitude (in ATR) scales the result away from the 0.5 neutral      |
//| midpoint in either direction - a flat market can't confirm or       |
//| deny either claim.                                                   |
//+------------------------------------------------------------------+
double CLS_TrendAlignmentQuality(const SSetupContext &ctx, const SSetupSignal &signal)
{
   const int    driftLookback = 20;
   const double recentClose   = iClose(ctx.symbol, PERIOD_CURRENT, 1);
   const double priorClose    = iClose(ctx.symbol, PERIOD_CURRENT, driftLookback + 1);
   if(recentClose <= 0.0 || priorClose <= 0.0)
      return 0.5; // insufficient history - neutral

   const double driftPoints  = recentClose - priorClose;
   const bool   driftUp      = driftPoints > 0.0;
   const bool   directionUp  = (signal.direction == CLS_DIR_BUY);

   bool agrees = (driftUp == directionUp);
   if(signal.setupClass == CLS_CLASS_REVERSAL)
      agrees = !agrees;

   const double driftStrength = MathMin(1.0, MathAbs(driftPoints) / MathMax(ctx.atrValue * 3.0, CLS_PRICE_EPSILON));
   const double quality       = agrees ? (0.5 + 0.5 * driftStrength) : (0.5 - 0.5 * driftStrength);
   return MathMax(0.0, MathMin(1.0, quality));
}

//+------------------------------------------------------------------+
//| Rewards signals firing near a known liquidity level (Asian or      |
//| previous-day high/low, from the shared LevelCache) - real          |
//| resting-order clusters, not just any price. Setups that already     |
//| trade off these exact levels (A, B) will usually score this near    |
//| 1.0 by construction; this mainly differentiates C/D/E.              |
//+------------------------------------------------------------------+
double CLS_LiquidityContextQuality(const SSetupContext &ctx, const SSetupSignal &signal)
{
   if(!g_Levels.isValid)
      return 0.5; // no cached levels yet - neutral

   double levels[4];
   levels[0] = g_Levels.asianHigh;
   levels[1] = g_Levels.asianLow;
   levels[2] = g_Levels.prevDayHigh;
   levels[3] = g_Levels.prevDayLow;

   double nearestDist = -1.0;
   for(int i = 0; i < 4; i++)
   {
      if(levels[i] <= 0.0)
         continue;
      const double dist = MathAbs(signal.entryPrice - levels[i]);
      if(nearestDist < 0.0 || dist < nearestDist)
         nearestDist = dist;
   }
   if(nearestDist < 0.0)
      return 0.5;

   const double distInATR = nearestDist / MathMax(ctx.atrValue, CLS_PRICE_EPSILON);
   // Within ~0.5 ATR of a known level => strong context; 3+ ATR away => weak.
   return MathMax(0.0, MathMin(1.0, 1.0 - distInATR / 3.0));
}

//+------------------------------------------------------------------+
//| Fraction of the last few closed bars that already moved in the     |
//| signal's direction - cheap momentum confirmation with no new        |
//| indicator handle, consistent with this module's existing closed-     |
//| bar-only price reads.                                                 |
//+------------------------------------------------------------------+
double CLS_MomentumConfirmationQuality(const string symbol, const SSetupSignal &signal)
{
   const int barsToCheck = 3;
   int agree = 0, total = 0;

   for(int s = 1; s <= barsToCheck; s++)
   {
      const double o = iOpen(symbol, PERIOD_CURRENT, s);
      const double c = iClose(symbol, PERIOD_CURRENT, s);
      if(o <= 0.0 || c <= 0.0)
         continue;

      total++;
      const bool barUp = c > o;
      if(barUp == (signal.direction == CLS_DIR_BUY))
         agree++;
   }

   return (total > 0) ? ((double)agree / (double)total) : 0.5;
}

//+------------------------------------------------------------------+
//| Combines the signal's own trigger quality (rawStrength) with a     |
//| weighted average of six context-quality reads into a single 0..100  |
//| score. Returns 0 for an invalid signal.                              |
//+------------------------------------------------------------------+
double CLS_ComputeScore(const SSetupContext &ctx, const SSetupSignal &signal)
{
   if(!signal.isValid)
      return CLS_SCORE_MIN;

   const double qTrend     = CLS_TrendAlignmentQuality(ctx, signal);
   const double qATR       = CLS_ATRRegimeQuality(ctx.atrRegime);
   const double qSession   = CLS_SessionQuality(ctx.session);
   const double qSpread    = CLS_SpreadQuality(ctx.spreadPoints, g_SymbolProfile.maxSpreadPoints);
   const double qLiquidity = CLS_LiquidityContextQuality(ctx, signal);
   const double qMomentum  = CLS_MomentumConfirmationQuality(ctx.symbol, signal);

   const double weightSum = MathMax(CLS_PRICE_EPSILON,
      InpWeightTrendAlignment + InpWeightVolatilityRegime + InpWeightSessionQuality +
      InpWeightSpreadCondition + InpWeightLiquidityContext + InpWeightMomentumConfirmation);

   const double contextQuality =
      (InpWeightTrendAlignment       * qTrend +
       InpWeightVolatilityRegime     * qATR +
       InpWeightSessionQuality       * qSession +
       InpWeightSpreadCondition      * qSpread +
       InpWeightLiquidityContext     * qLiquidity +
       InpWeightMomentumConfirmation * qMomentum) / weightSum;

   const double raw = CLS_SCORE_MAX * signal.rawStrength * contextQuality;
   return MathMax(CLS_SCORE_MIN, MathMin(CLS_SCORE_MAX, raw));
}

#endif // CLSAGENT_SCOREENGINE_MQH
