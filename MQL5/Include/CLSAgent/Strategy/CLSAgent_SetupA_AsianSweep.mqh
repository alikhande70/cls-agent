//+------------------------------------------------------------------+
//|                                  CLSAgent_SetupA_AsianSweep.mqh  |
//|   CLS Agent v2.4+ - Strategy / Setup A - Asian Sweep - Part 3    |
//|                                                                    |
//|   Liquidity grab of the Asian-session range once London/NewYork    |
//|   trading is underway: the closed bar pierces beyond the Asian     |
//|   high or low by more than noise (ATR fraction) and closes back    |
//|   inside the range, signaling a reversal away from the sweep.      |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_SETUPA_ASIANSWEEP_MQH
#define CLSAGENT_SETUPA_ASIANSWEEP_MQH

#include "../Core/CLSAgent_Constants.mqh"
#include "../Core/CLSAgent_Types.mqh"
#include "../Core/CLSAgent_Inputs.mqh"
#include "../Market/CLSAgent_LevelCache.mqh"
#include "CLSAgent_SetupContext.mqh"

bool CLS_DetectSetupA_AsianSweep(const SSetupContext &ctx, SSetupSignal &signal)
{
   if(!InpEnableSetupA)
      return false;
   if(!g_Levels.isValid)
      return false;
   // The Asian range is only meaningful liquidity once that session has handed
   // off - sweeping it during the Asian session itself is not a real grab.
   if(ctx.session != CLS_SESSION_LONDON && ctx.session != CLS_SESSION_NEWYORK && ctx.session != CLS_SESSION_OVERLAP)
      return false;

   const string symbol = ctx.symbol;
   const double high1   = iHigh(symbol, PERIOD_CURRENT, 1);
   const double low1    = iLow(symbol, PERIOD_CURRENT, 1);
   const double close1  = iClose(symbol, PERIOD_CURRENT, 1);

   const double minPierce = ctx.atrValue * InpSweepMinPierceATRFrac;

   // Bearish sweep: pierced above the Asian high, closed back below it.
   if(high1 > g_Levels.asianHigh + minPierce && close1 < g_Levels.asianHigh)
   {
      signal.setupType   = CLS_SETUP_A_ASIAN_SWEEP;
      signal.direction   = CLS_DIR_SELL;
      signal.barTime     = ctx.barTime;
      signal.entryPrice  = close1;
      CLS_BuildStopsFromATR(CLS_DIR_SELL, close1, ctx.atrValue, InpStopLossATRMultiplier, InpTakeProfitRMultiple,
                             signal.stopLoss, signal.takeProfit);
      signal.stopLoss    = MathMax(signal.stopLoss, high1 + ctx.atrValue * 0.1); // clear the sweep wick
      signal.rawStrength = MathMin(1.0, (high1 - g_Levels.asianHigh) / MathMax(ctx.atrValue, CLS_PRICE_EPSILON));
      signal.isValid     = true;
      return true;
   }

   // Bullish sweep: pierced below the Asian low, closed back above it.
   if(low1 < g_Levels.asianLow - minPierce && close1 > g_Levels.asianLow)
   {
      signal.setupType   = CLS_SETUP_A_ASIAN_SWEEP;
      signal.direction   = CLS_DIR_BUY;
      signal.barTime     = ctx.barTime;
      signal.entryPrice  = close1;
      CLS_BuildStopsFromATR(CLS_DIR_BUY, close1, ctx.atrValue, InpStopLossATRMultiplier, InpTakeProfitRMultiple,
                             signal.stopLoss, signal.takeProfit);
      signal.stopLoss    = MathMin(signal.stopLoss, low1 - ctx.atrValue * 0.1);
      signal.rawStrength = MathMin(1.0, (g_Levels.asianLow - low1) / MathMax(ctx.atrValue, CLS_PRICE_EPSILON));
      signal.isValid     = true;
      return true;
   }

   return false;
}

#endif // CLSAGENT_SETUPA_ASIANSWEEP_MQH
