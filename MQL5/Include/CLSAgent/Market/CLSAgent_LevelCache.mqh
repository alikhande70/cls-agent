//+------------------------------------------------------------------+
//|                                          CLSAgent_LevelCache.mqh |
//|   CLS Agent v2.4+ - Market / Key Level Cache - Part 2            |
//|                                                                    |
//|   Caches the liquidity levels the Setup Detector (Part 3) and      |
//|   Trailing-to-Liquidity (Part 7) read every bar: previous day      |
//|   high/low and today's Asian session high/low. Recomputed once     |
//|   per new broker day, not every bar, since these levels are fixed  |
//|   for the day once the Asian session has closed.                   |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_LEVELCACHE_MQH
#define CLSAGENT_LEVELCACHE_MQH

#include "../Core/CLSAgent_Inputs.mqh"
#include "../Core/CLSAgent_Utils.mqh"

#define CLS_LEVELCACHE_ASIAN_SCAN_BARS 200

struct SLevelCache
{
   double   prevDayHigh;
   double   prevDayLow;
   double   asianHigh;
   double   asianLow;
   datetime cachedForDay; // midnight of the broker day these levels belong to
   bool     isValid;

   SLevelCache()
   {
      prevDayHigh  = 0.0;
      prevDayLow   = 0.0;
      asianHigh    = 0.0;
      asianLow     = 0.0;
      cachedForDay = 0;
      isValid      = false;
   }
};

SLevelCache g_Levels;

datetime CLS_TodayMidnight()
{
   const datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
}

bool CLS_LevelCache_NeedsUpdate()
{
   return CLS_TodayMidnight() != g_Levels.cachedForDay;
}

//+------------------------------------------------------------------+
//| Rebuilds previous-day H/L and today's Asian-session H/L. Returns   |
//| false (and leaves the previous cache intact) if D1 history for     |
//| yesterday is not yet available, e.g. right after attaching the EA  |
//| with insufficient downloaded history.                              |
//+------------------------------------------------------------------+
bool CLS_LevelCache_Update(const string symbol)
{
   const double prevHigh = iHigh(symbol, PERIOD_D1, 1);
   const double prevLow  = iLow(symbol, PERIOD_D1, 1);
   if(prevHigh <= 0.0 || prevLow <= 0.0)
   {
      CLS_Log(CLS_LOG_WARNING, "LevelCache", "D1 history not ready yet for " + symbol + ", keeping previous levels.");
      return false;
   }

   g_Levels.prevDayHigh = prevHigh;
   g_Levels.prevDayLow  = prevLow;

   const datetime todayMidnight = CLS_TodayMidnight();
   const datetime asianStart    = todayMidnight + InpSessionAsianStartHour * 3600;
   const datetime asianEnd      = todayMidnight + InpSessionAsianEndHour   * 3600;

   double hi = -DBL_MAX, lo = DBL_MAX;
   bool   found = false;

   for(int i = 0; i < CLS_LEVELCACHE_ASIAN_SCAN_BARS; i++)
   {
      const datetime barTime = iTime(symbol, PERIOD_M15, i);
      if(barTime == 0 || barTime < asianStart)
         break; // walked past the start of the window, nothing older matters

      if(barTime >= asianStart && barTime < asianEnd)
      {
         hi = MathMax(hi, iHigh(symbol, PERIOD_M15, i));
         lo = MathMin(lo, iLow(symbol, PERIOD_M15, i));
         found = true;
      }
   }

   if(found)
   {
      g_Levels.asianHigh = hi;
      g_Levels.asianLow  = lo;
   }
   else
   {
      CLS_Log(CLS_LOG_WARNING, "LevelCache", "Could not locate Asian-session bars yet for " + symbol + ".");
   }

   g_Levels.cachedForDay = todayMidnight;
   g_Levels.isValid      = found;
   return found;
}

#endif // CLSAGENT_LEVELCACHE_MQH
