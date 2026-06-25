//+------------------------------------------------------------------+
//|                                   CLSAgent_SetupB_DailyHunt.mqh  |
//|   CLS Agent v2.4+ - Strategy / Setup B - Daily Hunt - Part 3     |
//|                                                                    |
//|   Same liquidity-sweep logic as Setup A but targets the previous   |
//|   day's high/low - a level resting orders cluster around in any    |
//|   session, not just after the Asian range closes.                  |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_SETUPB_DAILYHUNT_MQH
#define CLSAGENT_SETUPB_DAILYHUNT_MQH

#include "../Core/CLSAgent_Constants.mqh"
#include "../Core/CLSAgent_Types.mqh"
#include "../Core/CLSAgent_Inputs.mqh"
#include "../Market/CLSAgent_LevelCache.mqh"
#include "CLSAgent_SetupContext.mqh"

bool CLS_DetectSetupB_DailyHunt(const SSetupContext &ctx, SSetupSignal &signal)
{
   if(!InpEnableSetupB)
      return false;
   if(!g_Levels.isValid)
      return false;

   const string symbol = ctx.symbol;
   const double high1   = iHigh(symbol, PERIOD_CURRENT, 1);
   const double low1    = iLow(symbol, PERIOD_CURRENT, 1);
   const double close1  = iClose(symbol, PERIOD_CURRENT, 1);

   const double minPierce = ctx.atrValue * InpSweepMinPierceATRFrac;

   // Bearish sweep: pierced above yesterday's high, closed back below it.
   if(high1 > g_Levels.prevDayHigh + minPierce && close1 < g_Levels.prevDayHigh)
   {
      signal.setupType   = CLS_SETUP_B_DAILY_HUNT;
      signal.setupClass  = CLS_CLASS_REVERSAL;
      signal.direction   = CLS_DIR_SELL;
      signal.barTime     = ctx.barTime;
      signal.entryPrice  = close1;
      CLS_BuildStopsFromATR(CLS_DIR_SELL, close1, ctx.atrValue, InpStopLossATRMultiplier, InpTakeProfitRMultiple,
                             signal.stopLoss, signal.takeProfit);
      signal.stopLoss          = MathMax(signal.stopLoss, high1 + ctx.atrValue * 0.1);
      signal.invalidationLevel = high1;
      signal.rawStrength = MathMin(1.0, (high1 - g_Levels.prevDayHigh) / MathMax(ctx.atrValue, CLS_PRICE_EPSILON));
      signal.confidence  = signal.rawStrength * 100.0;
      signal.isValid     = true;
      return true;
   }

   // Bullish sweep: pierced below yesterday's low, closed back above it.
   if(low1 < g_Levels.prevDayLow - minPierce && close1 > g_Levels.prevDayLow)
   {
      signal.setupType   = CLS_SETUP_B_DAILY_HUNT;
      signal.setupClass  = CLS_CLASS_REVERSAL;
      signal.direction   = CLS_DIR_BUY;
      signal.barTime     = ctx.barTime;
      signal.entryPrice  = close1;
      CLS_BuildStopsFromATR(CLS_DIR_BUY, close1, ctx.atrValue, InpStopLossATRMultiplier, InpTakeProfitRMultiple,
                             signal.stopLoss, signal.takeProfit);
      signal.stopLoss          = MathMin(signal.stopLoss, low1 - ctx.atrValue * 0.1);
      signal.invalidationLevel = low1;
      signal.rawStrength = MathMin(1.0, (g_Levels.prevDayLow - low1) / MathMax(ctx.atrValue, CLS_PRICE_EPSILON));
      signal.confidence  = signal.rawStrength * 100.0;
      signal.isValid     = true;
      return true;
   }

   return false;
}

#endif // CLSAGENT_SETUPB_DAILYHUNT_MQH
