//+------------------------------------------------------------------+
//|                                         CLSAgent_BasketLog.mqh   |
//|   CLS Agent v2.4+ - Memory / Basket Log - Part 8                 |
//|                                                                    |
//|   Reuses CLSAgent_BasketRisk.mqh's own scan (same source of truth    |
//|   Risk Engine and Basket Execution already trust) rather than         |
//|   keeping a separate tally of basket composition. Runs once per       |
//|   closed bar (same cadence as Position Manager) and writes a row        |
//|   only when a direction's composition actually changed since the        |
//|   last bar - order count changed (opened/burst add/manual close), or      |
//|   total lots changed at the same order count (a partial exit shrinks       |
//|   totalLots without changing ordersCount) - not unconditionally every       |
//|   bar.                                                                       |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_BASKETLOG_MQH
#define CLSAGENT_BASKETLOG_MQH

#include "../Core/CLSAgent_Types.mqh"
#include "../Core/CLSAgent_Utils.mqh"
#include "../Risk/CLSAgent_BasketRisk.mqh"
#include "CLSAgent_CsvWriter.mqh"

int    g_BasketLogLastCount[2]; // index 0 = BUY, index 1 = SELL
double g_BasketLogLastLots[2];  // index 0 = BUY, index 1 = SELL

int CLS_BasketLog_DirIndex(const ENUM_CLS_DIRECTION direction) { return (direction == CLS_DIR_BUY) ? 0 : 1; }

void CLS_BasketLog_CheckDirection(const string symbol, const ENUM_CLS_DIRECTION direction)
{
   SBasketInfo basket;
   const bool  hasBasket = CLS_ScanCurrentBasket(symbol, direction, basket);
   const int   count     = hasBasket ? basket.ordersCount : 0;
   const double lots     = hasBasket ? basket.totalLots   : 0.0;
   const int   idx       = CLS_BasketLog_DirIndex(direction);

   if(count == g_BasketLogLastCount[idx] && CLS_IsDoubleEqual(lots, g_BasketLogLastLots[idx]))
      return;

   static const string header = "time,symbol,direction,ordersCount,totalLots,averageEntry,isLosing,riskPercent";
   const string line = StringFormat("%s,%s,%s,%d,%.2f,%.5f,%s,%.2f",
      TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), symbol, CLS_DirectionToString(direction),
      count, basket.totalLots, basket.averageEntry, (basket.isLosing ? "true" : "false"), basket.totalRiskPercent);
   CLS_Csv_AppendLine("baskets.csv", header, line);

   g_BasketLogLastCount[idx] = count;
   g_BasketLogLastLots[idx]  = lots;
}

//+------------------------------------------------------------------+
//| Call once per closed bar, after Position Manager has already         |
//| applied this bar's breakeven/partial-exit/trailing actions, so a       |
//| basket that shrank from a partial exit this same bar is reflected.      |
//+------------------------------------------------------------------+
void CLS_BasketLog_Update(const string symbol)
{
   CLS_BasketLog_CheckDirection(symbol, CLS_DIR_BUY);
   CLS_BasketLog_CheckDirection(symbol, CLS_DIR_SELL);
}

#endif // CLSAGENT_BASKETLOG_MQH
