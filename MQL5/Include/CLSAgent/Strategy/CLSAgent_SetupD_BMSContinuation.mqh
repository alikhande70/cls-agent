//+------------------------------------------------------------------+
//|                            CLSAgent_SetupD_BMSContinuation.mqh   |
//|   CLS Agent v2.4+ - Strategy / Setup D - Break-of-Market-         |
//|   Structure Continuation - Part 3                                |
//|                                                                    |
//|   Two-phase, stateful setup: (1) a closed bar breaks a recent      |
//|   fractal swing with a strong body -> arm; (2) on a later closed   |
//|   bar, a candle back in the break direction while price still      |
//|   holds beyond the broken level -> fire the continuation entry.    |
//|   Single-symbol-per-chart in v1, so one static state is sufficient |
//|   (see Multi-Symbol Manager limitation noted in Part 1).           |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_SETUPD_BMSCONTINUATION_MQH
#define CLSAGENT_SETUPD_BMSCONTINUATION_MQH

#include "../Core/CLSAgent_Constants.mqh"
#include "../Core/CLSAgent_Types.mqh"
#include "../Core/CLSAgent_Inputs.mqh"
#include "CLSAgent_SetupContext.mqh"

#define CLS_BMS_MAX_PULLBACK_WAIT_BARS 6

struct SBMSState
{
   bool                armed;
   ENUM_CLS_DIRECTION  direction;
   double              breakLevel;
   double              breakBodyStrength; // 0..1, breakout candle's body/ATR ratio - reused as rawStrength when the pullback fires
   int                 barsSinceBreak;

   SBMSState()
   {
      armed             = false;
      direction         = CLS_DIR_NONE;
      breakLevel        = 0.0;
      breakBodyStrength = 0.0;
      barsSinceBreak    = 0;
   }
};

SBMSState g_BMSState;

bool CLS_DetectSetupD_BMSContinuation(const SSetupContext &ctx, SSetupSignal &signal)
{
   if(!InpEnableSetupD)
      return false;

   const string symbol = ctx.symbol;
   const double close1 = iClose(symbol, PERIOD_CURRENT, 1);
   const double open1  = iOpen(symbol, PERIOD_CURRENT, 1);
   const double body1  = CLS_CandleBody(symbol, PERIOD_CURRENT, 1);

   // Phase 2: already armed from an earlier break - look for the pullback
   // candle that triggers entry, or invalidate/expire the armed state.
   if(g_BMSState.armed)
   {
      g_BMSState.barsSinceBreak++;

      if(g_BMSState.direction == CLS_DIR_BUY)
      {
         if(close1 < g_BMSState.breakLevel)
         {
            g_BMSState.armed = false; // broke back through - structure invalidated
         }
         else if(close1 > open1)
         {
            signal.setupType   = CLS_SETUP_D_BMS_CONTINUATION;
            signal.direction   = CLS_DIR_BUY;
            signal.barTime     = ctx.barTime;
            signal.entryPrice  = close1;
            CLS_BuildStopsFromATR(CLS_DIR_BUY, close1, ctx.atrValue, InpStopLossATRMultiplier, InpTakeProfitRMultiple,
                                   signal.stopLoss, signal.takeProfit);
            signal.stopLoss    = MathMin(signal.stopLoss, g_BMSState.breakLevel - ctx.atrValue * 0.1);
            signal.rawStrength = g_BMSState.breakBodyStrength;
            signal.isValid     = true;
            g_BMSState.armed = false; // one shot per break
            return true;
         }
      }
      else if(g_BMSState.direction == CLS_DIR_SELL)
      {
         if(close1 > g_BMSState.breakLevel)
         {
            g_BMSState.armed = false;
         }
         else if(close1 < open1)
         {
            signal.setupType   = CLS_SETUP_D_BMS_CONTINUATION;
            signal.direction   = CLS_DIR_SELL;
            signal.barTime     = ctx.barTime;
            signal.entryPrice  = close1;
            CLS_BuildStopsFromATR(CLS_DIR_SELL, close1, ctx.atrValue, InpStopLossATRMultiplier, InpTakeProfitRMultiple,
                                   signal.stopLoss, signal.takeProfit);
            signal.stopLoss    = MathMax(signal.stopLoss, g_BMSState.breakLevel + ctx.atrValue * 0.1);
            signal.rawStrength = g_BMSState.breakBodyStrength;
            signal.isValid     = true;
            g_BMSState.armed = false;
            return true;
         }
      }

      if(g_BMSState.barsSinceBreak > CLS_BMS_MAX_PULLBACK_WAIT_BARS)
         g_BMSState.armed = false; // pullback never came in time

      if(g_BMSState.armed)
         return false; // still waiting, nothing to emit this bar
   }

   // Phase 1: not armed - look for a fresh, strong-bodied break of structure.
   double swingHigh, swingLow;
   int    swingHighShift, swingLowShift;
   const bool hasSwingHigh = CLS_FindSwingHigh(symbol, PERIOD_CURRENT, 2, InpSwingLookbackBars, InpFractalWingBars,
                                                swingHigh, swingHighShift);
   const bool hasSwingLow  = CLS_FindSwingLow(symbol, PERIOD_CURRENT, 2, InpSwingLookbackBars, InpFractalWingBars,
                                               swingLow, swingLowShift);

   const double minBody = ctx.atrValue * InpBMSMinBodyATRPct;
   const double bodyStrength = MathMin(1.0, body1 / MathMax(ctx.atrValue, CLS_PRICE_EPSILON));

   if(hasSwingHigh && close1 > swingHigh && body1 >= minBody && close1 > open1)
   {
      g_BMSState.armed             = true;
      g_BMSState.direction         = CLS_DIR_BUY;
      g_BMSState.breakLevel        = swingHigh;
      g_BMSState.breakBodyStrength = bodyStrength;
      g_BMSState.barsSinceBreak    = 0;
      return false; // armed now, continuation entry fires on a later pullback bar
   }

   if(hasSwingLow && close1 < swingLow && body1 >= minBody && close1 < open1)
   {
      g_BMSState.armed             = true;
      g_BMSState.direction         = CLS_DIR_SELL;
      g_BMSState.breakLevel        = swingLow;
      g_BMSState.breakBodyStrength = bodyStrength;
      g_BMSState.barsSinceBreak    = 0;
      return false;
   }

   return false;
}

#endif // CLSAGENT_SETUPD_BMSCONTINUATION_MQH
