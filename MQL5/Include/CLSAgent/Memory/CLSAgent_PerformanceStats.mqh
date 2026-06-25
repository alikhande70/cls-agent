//+------------------------------------------------------------------+
//|                                    CLSAgent_PerformanceStats.mqh |
//|   CLS Agent v2.4+ - Memory / Performance Stats - Part 8          |
//|                                                                    |
//|   Running counters fed exclusively by CLSAgent_TradeLog.mqh's       |
//|   closed-deal hook, since the deal's own profit/swap/commission is   |
//|   the only authoritative source for a trade's realized P/L - never    |
//|   re-derived from anything this EA calculated at entry time.           |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_PERFORMANCESTATS_MQH
#define CLSAGENT_PERFORMANCESTATS_MQH

#include "../Core/CLSAgent_Types.mqh"
#include "../Core/CLSAgent_Constants.mqh"
#include "../Core/CLSAgent_Utils.mqh"

struct SPerformanceStats
{
   int    tradesClosed;
   int    wins;
   int    losses;
   double grossProfit;
   double grossLoss;

   SPerformanceStats()
   {
      tradesClosed = 0;
      wins         = 0;
      losses       = 0;
      grossProfit  = 0.0;
      grossLoss    = 0.0;
   }
};

// Index 0 holds running totals across every setup. Indices 1..CLS_MAX_SETUPS
// mirror ENUM_CLS_SETUP_TYPE's A..D values directly (they are defined as
// 1..4) - CLS_SETUP_NONE's value of 0 coincides with the totals slot, but
// CLS_PerformanceStats_Update() never indexes into it for a real setup.
SPerformanceStats g_PerfStats[CLS_MAX_SETUPS + 1];

double CLS_PerformanceStats_WinRate(const SPerformanceStats &s)
{
   return (s.tradesClosed > 0) ? (100.0 * s.wins / s.tradesClosed) : 0.0;
}

double CLS_PerformanceStats_ProfitFactor(const SPerformanceStats &s)
{
   return (s.grossLoss > 0.0) ? (s.grossProfit / s.grossLoss) : 0.0;
}

void CLS_PerformanceStats_Update(const ENUM_CLS_SETUP_TYPE setupType, const double profit)
{
   const int idx = (int)setupType;

   g_PerfStats[0].tradesClosed++;
   if(idx != 0)
      g_PerfStats[idx].tradesClosed++;

   if(profit >= 0.0)
   {
      g_PerfStats[0].wins++;
      g_PerfStats[0].grossProfit += profit;
      if(idx != 0)
      {
         g_PerfStats[idx].wins++;
         g_PerfStats[idx].grossProfit += profit;
      }
   }
   else
   {
      g_PerfStats[0].losses++;
      g_PerfStats[0].grossLoss += -profit;
      if(idx != 0)
      {
         g_PerfStats[idx].losses++;
         g_PerfStats[idx].grossLoss += -profit;
      }
   }

   CLS_Log(CLS_LOG_INFO, "PerformanceStats", StringFormat(
      "Closed trade setup=%s profit=%.2f | totals trades=%d winRate=%.1f%% profitFactor=%.2f",
      EnumToString(setupType), profit, g_PerfStats[0].tradesClosed,
      CLS_PerformanceStats_WinRate(g_PerfStats[0]), CLS_PerformanceStats_ProfitFactor(g_PerfStats[0])));
}

#endif // CLSAGENT_PERFORMANCESTATS_MQH
