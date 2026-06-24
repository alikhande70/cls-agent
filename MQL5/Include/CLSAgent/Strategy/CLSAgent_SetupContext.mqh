//+------------------------------------------------------------------+
//|                                       CLSAgent_SetupContext.mqh  |
//|   CLS Agent v2.4+ - Strategy / Shared Price-Action Helpers       |
//|   Part 3                                                         |
//|                                                                    |
//|   Helpers shared by every Setup A-D detector: candle anatomy,      |
//|   fractal swing pivots, Fair Value Gap detection and ATR-based     |
//|   stop/target construction. Every read here uses shift>=1 only -   |
//|   Rule #6 (closed-bar confirmation) is enforced at this shared      |
//|   layer so no individual setup can accidentally peek at shift=0.   |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_SETUPCONTEXT_MQH
#define CLSAGENT_SETUPCONTEXT_MQH

#include "../Core/CLSAgent_Types.mqh"

double CLS_CandleBody(const string symbol, const ENUM_TIMEFRAMES tf, const int shift)
{
   return MathAbs(iClose(symbol, tf, shift) - iOpen(symbol, tf, shift));
}

double CLS_CandleRange(const string symbol, const ENUM_TIMEFRAMES tf, const int shift)
{
   return iHigh(symbol, tf, shift) - iLow(symbol, tf, shift);
}

bool CLS_IsBullishClose(const string symbol, const ENUM_TIMEFRAMES tf, const int shift)
{
   return iClose(symbol, tf, shift) > iOpen(symbol, tf, shift);
}

bool CLS_IsBearishClose(const string symbol, const ENUM_TIMEFRAMES tf, const int shift)
{
   return iClose(symbol, tf, shift) < iOpen(symbol, tf, shift);
}

//+------------------------------------------------------------------+
//| Fractal swing-high pivot: a closed bar whose high is the highest  |
//| of itself and wingBars closed bars on each side. Scans from        |
//| searchStartShift outward to searchStartShift+lookbackBars,         |
//| returning the most recent (smallest shift) qualifying pivot.       |
//| Candidates whose wing would reach into the still-forming bar       |
//| (shift 0) are skipped outright, never just trimmed.                |
//+------------------------------------------------------------------+
bool CLS_FindSwingHigh(const string symbol, const ENUM_TIMEFRAMES tf,
                        const int searchStartShift, const int lookbackBars, const int wingBars,
                        double &levelOut, int &shiftOut)
{
   for(int c = searchStartShift; c <= searchStartShift + lookbackBars; c++)
   {
      if(c - wingBars < 1)
         continue;

      const double candidate = iHigh(symbol, tf, c);
      if(candidate <= 0.0)
         return false; // ran out of history

      bool isPivot = true;
      for(int w = 1; w <= wingBars && isPivot; w++)
      {
         if(iHigh(symbol, tf, c - w) > candidate) isPivot = false;
         if(iHigh(symbol, tf, c + w) > candidate) isPivot = false;
      }

      if(isPivot)
      {
         levelOut = candidate;
         shiftOut = c;
         return true;
      }
   }
   return false;
}

bool CLS_FindSwingLow(const string symbol, const ENUM_TIMEFRAMES tf,
                       const int searchStartShift, const int lookbackBars, const int wingBars,
                       double &levelOut, int &shiftOut)
{
   for(int c = searchStartShift; c <= searchStartShift + lookbackBars; c++)
   {
      if(c - wingBars < 1)
         continue;

      const double candidate = iLow(symbol, tf, c);
      if(candidate <= 0.0)
         return false;

      bool isPivot = true;
      for(int w = 1; w <= wingBars && isPivot; w++)
      {
         if(iLow(symbol, tf, c - w) < candidate) isPivot = false;
         if(iLow(symbol, tf, c + w) < candidate) isPivot = false;
      }

      if(isPivot)
      {
         levelOut = candidate;
         shiftOut = c;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| 3-candle Fair Value Gap, evaluated on the closed bars at           |
//| shift (newest of the three), shift+1 (impulse) and shift+2         |
//| (oldest). Bullish: the newest bar's low sits above the oldest      |
//| bar's high (gap up, never touched by the impulse candle).          |
//+------------------------------------------------------------------+
bool CLS_DetectBullishFVG(const string symbol, const ENUM_TIMEFRAMES tf, const int shift,
                           const double minGapSize, double &gapLowOut, double &gapHighOut)
{
   const double highOld = iHigh(symbol, tf, shift + 2);
   const double lowNew  = iLow(symbol, tf, shift);
   if(highOld <= 0.0 || lowNew <= 0.0)
      return false;

   if(lowNew - highOld >= minGapSize)
   {
      gapLowOut  = highOld;
      gapHighOut = lowNew;
      return true;
   }
   return false;
}

bool CLS_DetectBearishFVG(const string symbol, const ENUM_TIMEFRAMES tf, const int shift,
                           const double minGapSize, double &gapLowOut, double &gapHighOut)
{
   const double lowOld  = iLow(symbol, tf, shift + 2);
   const double highNew = iHigh(symbol, tf, shift);
   if(lowOld <= 0.0 || highNew <= 0.0)
      return false;

   if(lowOld - highNew >= minGapSize)
   {
      gapLowOut  = highNew;
      gapHighOut = lowOld;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| ATR-fraction based stop/target so Gold and Forex scale naturally   |
//| without separate hardcoded point distances (Rule #8). Setups may   |
//| still widen the stop further out to clear a sweep wick/level -     |
//| this only supplies the baseline distance.                          |
//+------------------------------------------------------------------+
void CLS_BuildStopsFromATR(const ENUM_CLS_DIRECTION direction, const double entryPrice, const double atrValue,
                            const double slMultiplier, const double tpRMultiple,
                            double &stopLossOut, double &takeProfitOut)
{
   const double stopDistance = atrValue * slMultiplier;

   if(direction == CLS_DIR_BUY)
   {
      stopLossOut   = entryPrice - stopDistance;
      takeProfitOut = entryPrice + stopDistance * tpRMultiple;
   }
   else if(direction == CLS_DIR_SELL)
   {
      stopLossOut   = entryPrice + stopDistance;
      takeProfitOut = entryPrice - stopDistance * tpRMultiple;
   }
   else
   {
      stopLossOut   = 0.0;
      takeProfitOut = 0.0;
   }
}

#endif // CLSAGENT_SETUPCONTEXT_MQH
