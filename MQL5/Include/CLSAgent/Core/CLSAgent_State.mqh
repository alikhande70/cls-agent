//+------------------------------------------------------------------+
//|                                            CLSAgent_State.mqh    |
//|   CLS Agent v2.4+ - Decision-Safe Contextual Liquidity Scalping  |
//|   Core / Runtime State - Part 1                                  |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_STATE_MQH
#define CLSAGENT_STATE_MQH

#include "CLSAgent_Types.mqh"

// Centralized runtime state for the EA instance running on one chart/symbol
// (Part 1 is single-symbol-per-chart only - see project v1 limitations).
// Part 1 only tracks generic lifecycle/bar/day bookkeeping; basket- and
// risk-specific fields are added once Parts 5-7 exist.
struct SEAState
{
   bool                 isInitialized;
   bool                 tradingAllowedByMode;  // recomputed every tick from InpMode/InpAutoTrade
   datetime             lastProcessedBarTime;  // last fully-closed bar already evaluated
   datetime             currentTradeDay;       // midnight timestamp of the current trading day (broker time)
   double               dailyStartBalance;
   double               dailyStartEquity;
   int                  ticksProcessed;
   string               activeSymbol;
   ENUM_CLS_ASSET_CLASS activeAssetClass;

   SEAState()
   {
      isInitialized        = false;
      tradingAllowedByMode = false;
      lastProcessedBarTime = 0;
      currentTradeDay      = 0;
      dailyStartBalance    = 0.0;
      dailyStartEquity     = 0.0;
      ticksProcessed       = 0;
      activeSymbol         = "";
      activeAssetClass     = CLS_ASSET_FOREX;
   }
};

SEAState g_State;

//+------------------------------------------------------------------+
//| Call once from OnInit() after inputs are validated.               |
//+------------------------------------------------------------------+
void CLS_State_Init(const string symbol, const ENUM_CLS_ASSET_CLASS assetClass)
{
   g_State.isInitialized        = true;
   g_State.tradingAllowedByMode = false;
   g_State.lastProcessedBarTime = 0;
   g_State.currentTradeDay      = 0;
   g_State.dailyStartBalance    = AccountInfoDouble(ACCOUNT_BALANCE);
   g_State.dailyStartEquity     = AccountInfoDouble(ACCOUNT_EQUITY);
   g_State.ticksProcessed       = 0;
   g_State.activeSymbol         = symbol;
   g_State.activeAssetClass     = assetClass;
}

//+------------------------------------------------------------------+
//| Returns true exactly once per newly closed bar on the given        |
//| timeframe. This is the gate that enforces Rule #6 (entries only    |
//| confirmed on a closed candle, never the forming one).              |
//+------------------------------------------------------------------+
bool CLS_State_IsNewBar(const string symbol, const ENUM_TIMEFRAMES timeframe)
{
   const datetime barTime = iTime(symbol, timeframe, 0);
   if(barTime == 0)
      return false; // history not ready yet

   if(barTime != g_State.lastProcessedBarTime)
   {
      g_State.lastProcessedBarTime = barTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Returns true once per new broker trading day and resets the daily  |
//| P/L baseline. Backs Rule #7 (DailyLoss must be checked before      |
//| entry) - the Risk Engine (Part 5) reads dailyStartBalance/Equity.  |
//+------------------------------------------------------------------+
bool CLS_State_RolloverDayIfNeeded()
{
   const datetime now      = TimeCurrent();
   const datetime midnight = now - (now % 86400);

   if(midnight != g_State.currentTradeDay)
   {
      g_State.currentTradeDay   = midnight;
      g_State.dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_State.dailyStartEquity  = AccountInfoDouble(ACCOUNT_EQUITY);
      return true;
   }
   return false;
}

#endif // CLSAGENT_STATE_MQH
