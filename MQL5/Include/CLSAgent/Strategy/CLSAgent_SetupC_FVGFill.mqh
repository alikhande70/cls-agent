//+------------------------------------------------------------------+
//|                                     CLSAgent_SetupC_FVGFill.mqh  |
//|   CLS Agent v2.4+ - Strategy / Setup C - FVG Fill - Part 3       |
//|                                                                    |
//|   Finds the nearest unfilled 3-candle Fair Value Gap behind the    |
//|   closed bar and waits for price to trade back into it. A close    |
//|   that rejects back out in the gap's original impulse direction    |
//|   is treated as a continuation entry off that imbalance.           |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_SETUPC_FVGFILL_MQH
#define CLSAGENT_SETUPC_FVGFILL_MQH

#include "../Core/CLSAgent_Constants.mqh"
#include "../Core/CLSAgent_Types.mqh"
#include "../Core/CLSAgent_Inputs.mqh"
#include "CLSAgent_SetupContext.mqh"

bool CLS_DetectSetupC_FVGFill(const SSetupContext &ctx, SSetupSignal &signal)
{
   if(!InpEnableSetupC)
      return false;

   const string symbol      = ctx.symbol;
   const double minGapSize  = ctx.atrValue * InpFVGMinSizeATRFrac;
   if(minGapSize <= 0.0)
      return false;

   const int lookback = MathMax(5, InpSwingLookbackBars);

   // Search starts at shift=2 so the gap is fully formed before the bar that
   // tests it (shift=1, the just-closed bar).
   bool   foundBull = false, foundBear = false;
   double bullLow = 0.0, bullHigh = 0.0, bearLow = 0.0, bearHigh = 0.0;

   for(int s = 2; s <= lookback && !(foundBull && foundBear); s++)
   {
      if(!foundBull)
         foundBull = CLS_DetectBullishFVG(symbol, PERIOD_CURRENT, s, minGapSize, bullLow, bullHigh);
      if(!foundBear)
         foundBear = CLS_DetectBearishFVG(symbol, PERIOD_CURRENT, s, minGapSize, bearLow, bearHigh);
   }

   const double low1   = iLow(symbol, PERIOD_CURRENT, 1);
   const double high1  = iHigh(symbol, PERIOD_CURRENT, 1);
   const double close1 = iClose(symbol, PERIOD_CURRENT, 1);
   const double open1  = iOpen(symbol, PERIOD_CURRENT, 1);

   if(foundBull)
   {
      const bool tradedIntoGap = (low1 <= bullHigh && high1 >= bullLow);
      const bool rejectedUp    = (close1 > open1) && (close1 >= bullLow);
      if(tradedIntoGap && rejectedUp)
      {
         signal.setupType   = CLS_SETUP_C_FVG_FILL;
         signal.direction   = CLS_DIR_BUY;
         signal.barTime     = ctx.barTime;
         signal.entryPrice  = close1;
         CLS_BuildStopsFromATR(CLS_DIR_BUY, close1, ctx.atrValue, InpStopLossATRMultiplier, InpTakeProfitRMultiple,
                                signal.stopLoss, signal.takeProfit);
         signal.stopLoss    = MathMin(signal.stopLoss, bullLow - ctx.atrValue * 0.1);
         signal.rawStrength = MathMin(1.0, (bullHigh - bullLow) / MathMax(ctx.atrValue, CLS_PRICE_EPSILON));
         signal.isValid     = true;
         return true;
      }
   }

   if(foundBear)
   {
      const bool tradedIntoGap = (low1 <= bearHigh && high1 >= bearLow);
      const bool rejectedDown  = (close1 < open1) && (close1 <= bearHigh);
      if(tradedIntoGap && rejectedDown)
      {
         signal.setupType   = CLS_SETUP_C_FVG_FILL;
         signal.direction   = CLS_DIR_SELL;
         signal.barTime     = ctx.barTime;
         signal.entryPrice  = close1;
         CLS_BuildStopsFromATR(CLS_DIR_SELL, close1, ctx.atrValue, InpStopLossATRMultiplier, InpTakeProfitRMultiple,
                                signal.stopLoss, signal.takeProfit);
         signal.stopLoss    = MathMax(signal.stopLoss, bearHigh + ctx.atrValue * 0.1);
         signal.rawStrength = MathMin(1.0, (bearHigh - bearLow) / MathMax(ctx.atrValue, CLS_PRICE_EPSILON));
         signal.isValid     = true;
         return true;
      }
   }

   return false;
}

#endif // CLSAGENT_SETUPC_FVGFILL_MQH
