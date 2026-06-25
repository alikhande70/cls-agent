//+------------------------------------------------------------------+
//|                       CLSAgent_SetupE_OrderBlockRejection.mqh    |
//|   CLS Agent v2.4+ - Strategy / Setup E - Order Block Rejection -  |
//|   Phase 2                                                         |
//|                                                                    |
//|   Two-phase, stateful setup, same shape as Setup D: (1) a closed   |
//|   bar breaks a recent fractal swing with a strong body (BOS) ->    |
//|   walk back to the last opposite-colored candle before that        |
//|   impulse - the order block - and arm on its range; (2) on a       |
//|   later closed bar, price trades back into the order block and     |
//|   rejects out of it in the original break direction -> fire the    |
//|   entry. Continuation-vs-reversal is classified at arm time by      |
//|   comparing the break direction against price drift over a longer   |
//|   lookback window - no new indicator, just a wider price read.      |
//|   Single-symbol-per-chart in v1, so one static state is sufficient  |
//|   (see Multi-Symbol Manager limitation noted in Part 1).            |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_SETUPE_ORDERBLOCKREJECTION_MQH
#define CLSAGENT_SETUPE_ORDERBLOCKREJECTION_MQH

#include "../Core/CLSAgent_Constants.mqh"
#include "../Core/CLSAgent_Types.mqh"
#include "../Core/CLSAgent_Inputs.mqh"
#include "CLSAgent_SetupContext.mqh"

struct SOrderBlockState
{
   bool                 armed;
   ENUM_CLS_DIRECTION   direction;
   ENUM_CLS_SETUP_CLASS setupClass;
   double               breakLevel;     // the swing level whose break defined the BOS
   double               obHigh;         // order-block candle's high
   double               obLow;          // order-block candle's low
   double               impulseBodyStrength; // 0..1, BOS impulse candle's body/ATR ratio
   int                  barsSinceBreak;

   SOrderBlockState()
   {
      armed               = false;
      direction           = CLS_DIR_NONE;
      setupClass          = CLS_CLASS_NONE;
      breakLevel          = 0.0;
      obHigh              = 0.0;
      obLow               = 0.0;
      impulseBodyStrength = 0.0;
      barsSinceBreak      = 0;
   }
};

SOrderBlockState g_OBState;

//+------------------------------------------------------------------+
//| Continuation if the break direction agrees with price drift over   |
//| a longer lookback (price was already heading that way); reversal    |
//| if the break fights that drift (this is the first sign of a flip).  |
//+------------------------------------------------------------------+
ENUM_CLS_SETUP_CLASS CLS_ClassifyOrderBlockSetup(const string symbol, const ENUM_CLS_DIRECTION direction, const double close1)
{
   const int    driftShift = InpSwingLookbackBars * 2 + 1;
   double       priorClose = iClose(symbol, PERIOD_CURRENT, driftShift);
   if(priorClose <= 0.0)
      priorClose = close1;

   const bool driftUp = close1 > priorClose;

   if(direction == CLS_DIR_BUY)
      return driftUp ? CLS_CLASS_CONTINUATION : CLS_CLASS_REVERSAL;
   if(direction == CLS_DIR_SELL)
      return (!driftUp) ? CLS_CLASS_CONTINUATION : CLS_CLASS_REVERSAL;
   return CLS_CLASS_NONE;
}

//+------------------------------------------------------------------+
//| Walks back from the impulse candle (shift=2 onward) looking for    |
//| the most recent candle of the opposite color - the order block.    |
//| Returns false if none is found within InpOBMaxLookbackBars.        |
//+------------------------------------------------------------------+
bool CLS_FindOrderBlockCandle(const string symbol, const bool impulseIsBullish, double &obHighOut, double &obLowOut)
{
   for(int s = 2; s <= 1 + InpOBMaxLookbackBars; s++)
   {
      const double o = iOpen(symbol, PERIOD_CURRENT, s);
      const double c = iClose(symbol, PERIOD_CURRENT, s);
      if(o <= 0.0 || c <= 0.0)
         return false; // ran out of history

      const bool isBearish = c < o;
      const bool isBullish = c > o;

      if(impulseIsBullish && isBearish)
      {
         obHighOut = iHigh(symbol, PERIOD_CURRENT, s);
         obLowOut  = iLow(symbol, PERIOD_CURRENT, s);
         return true;
      }
      if(!impulseIsBullish && isBullish)
      {
         obHighOut = iHigh(symbol, PERIOD_CURRENT, s);
         obLowOut  = iLow(symbol, PERIOD_CURRENT, s);
         return true;
      }
   }
   return false;
}

bool CLS_DetectSetupE_OrderBlockRejection(const SSetupContext &ctx, SSetupSignal &signal)
{
   if(!InpEnableSetupE)
      return false;

   const string symbol = ctx.symbol;
   const double close1 = iClose(symbol, PERIOD_CURRENT, 1);
   const double open1  = iOpen(symbol, PERIOD_CURRENT, 1);
   const double high1  = iHigh(symbol, PERIOD_CURRENT, 1);
   const double low1   = iLow(symbol, PERIOD_CURRENT, 1);

   // Phase 2: already armed from an earlier break - look for the bar that
   // returns into the order block and rejects, or invalidate/expire.
   if(g_OBState.armed)
   {
      g_OBState.barsSinceBreak++;

      if(g_OBState.direction == CLS_DIR_BUY)
      {
         if(close1 < g_OBState.obLow)
         {
            g_OBState.armed = false; // closed clean through the block - order block failed
         }
         else
         {
            const double wickDepth = g_OBState.obHigh - low1;
            const bool   tradedIn  = low1 <= g_OBState.obHigh;
            const bool   rejected  = close1 > open1 && close1 > g_OBState.obLow;
            const bool   wickOk    = wickDepth >= ctx.atrValue * InpOBMinRejectionWickATRFrac;

            if(tradedIn && rejected && wickOk)
            {
               const double wickQuality = MathMin(1.0, wickDepth / MathMax(ctx.atrValue, CLS_PRICE_EPSILON));
               signal.setupType   = CLS_SETUP_E_ORDER_BLOCK_REJECTION;
               signal.setupClass  = g_OBState.setupClass;
               signal.direction   = CLS_DIR_BUY;
               signal.barTime     = ctx.barTime;
               signal.entryPrice  = close1;
               CLS_BuildStopsFromATR(CLS_DIR_BUY, close1, ctx.atrValue, InpStopLossATRMultiplier, InpTakeProfitRMultiple,
                                      signal.stopLoss, signal.takeProfit);
               signal.stopLoss          = MathMin(signal.stopLoss, g_OBState.obLow - ctx.atrValue * 0.1);
               signal.invalidationLevel = g_OBState.obLow;
               signal.rawStrength = MathMax(0.0, MathMin(1.0, 0.5 * g_OBState.impulseBodyStrength + 0.5 * wickQuality));
               signal.confidence  = signal.rawStrength * 100.0;
               signal.isValid     = true;
               g_OBState.armed = false; // one shot per order block
               return true;
            }
         }
      }
      else if(g_OBState.direction == CLS_DIR_SELL)
      {
         if(close1 > g_OBState.obHigh)
         {
            g_OBState.armed = false;
         }
         else
         {
            const double wickDepth = high1 - g_OBState.obLow;
            const bool   tradedIn  = high1 >= g_OBState.obLow;
            const bool   rejected  = close1 < open1 && close1 < g_OBState.obHigh;
            const bool   wickOk    = wickDepth >= ctx.atrValue * InpOBMinRejectionWickATRFrac;

            if(tradedIn && rejected && wickOk)
            {
               const double wickQuality = MathMin(1.0, wickDepth / MathMax(ctx.atrValue, CLS_PRICE_EPSILON));
               signal.setupType   = CLS_SETUP_E_ORDER_BLOCK_REJECTION;
               signal.setupClass  = g_OBState.setupClass;
               signal.direction   = CLS_DIR_SELL;
               signal.barTime     = ctx.barTime;
               signal.entryPrice  = close1;
               CLS_BuildStopsFromATR(CLS_DIR_SELL, close1, ctx.atrValue, InpStopLossATRMultiplier, InpTakeProfitRMultiple,
                                      signal.stopLoss, signal.takeProfit);
               signal.stopLoss          = MathMax(signal.stopLoss, g_OBState.obHigh + ctx.atrValue * 0.1);
               signal.invalidationLevel = g_OBState.obHigh;
               signal.rawStrength = MathMax(0.0, MathMin(1.0, 0.5 * g_OBState.impulseBodyStrength + 0.5 * wickQuality));
               signal.confidence  = signal.rawStrength * 100.0;
               signal.isValid     = true;
               g_OBState.armed = false;
               return true;
            }
         }
      }

      if(g_OBState.barsSinceBreak > InpOBMaxWaitBars)
         g_OBState.armed = false; // price never returned in time

      if(g_OBState.armed)
         return false; // still waiting, nothing to emit this bar
   }

   // Phase 1: not armed - look for a fresh, strong-bodied break of structure,
   // then walk back to the order block that preceded it.
   double swingHigh, swingLow;
   int    swingHighShift, swingLowShift;
   const bool hasSwingHigh = CLS_FindSwingHigh(symbol, PERIOD_CURRENT, 2, InpSwingLookbackBars, InpFractalWingBars,
                                                swingHigh, swingHighShift);
   const bool hasSwingLow  = CLS_FindSwingLow(symbol, PERIOD_CURRENT, 2, InpSwingLookbackBars, InpFractalWingBars,
                                               swingLow, swingLowShift);

   const double body1        = CLS_CandleBody(symbol, PERIOD_CURRENT, 1);
   const double minBody      = ctx.atrValue * InpOBImpulseMinBodyATRPct;
   const double bodyStrength = MathMin(1.0, body1 / MathMax(ctx.atrValue, CLS_PRICE_EPSILON));

   if(hasSwingHigh && close1 > swingHigh && body1 >= minBody && close1 > open1)
   {
      double obHigh, obLow;
      if(CLS_FindOrderBlockCandle(symbol, true, obHigh, obLow))
      {
         g_OBState.armed               = true;
         g_OBState.direction            = CLS_DIR_BUY;
         g_OBState.setupClass           = CLS_ClassifyOrderBlockSetup(symbol, CLS_DIR_BUY, close1);
         g_OBState.breakLevel           = swingHigh;
         g_OBState.obHigh               = obHigh;
         g_OBState.obLow                = obLow;
         g_OBState.impulseBodyStrength  = bodyStrength;
         g_OBState.barsSinceBreak       = 0;
      }
      return false; // armed now (or no order block found) - either way nothing fires this bar
   }

   if(hasSwingLow && close1 < swingLow && body1 >= minBody && close1 < open1)
   {
      double obHigh, obLow;
      if(CLS_FindOrderBlockCandle(symbol, false, obHigh, obLow))
      {
         g_OBState.armed               = true;
         g_OBState.direction            = CLS_DIR_SELL;
         g_OBState.setupClass           = CLS_ClassifyOrderBlockSetup(symbol, CLS_DIR_SELL, close1);
         g_OBState.breakLevel           = swingLow;
         g_OBState.obHigh               = obHigh;
         g_OBState.obLow                = obLow;
         g_OBState.impulseBodyStrength  = bodyStrength;
         g_OBState.barsSinceBreak       = 0;
      }
      return false;
   }

   return false;
}

#endif // CLSAGENT_SETUPE_ORDERBLOCKREJECTION_MQH
