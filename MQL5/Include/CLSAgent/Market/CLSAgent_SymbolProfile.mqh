//+------------------------------------------------------------------+
//|                                      CLSAgent_SymbolProfile.mqh  |
//|   CLS Agent v2.4+ - Market / Symbol Profile - Part 2             |
//|                                                                    |
//|   Resolves Gold vs Forex for the chart symbol (Rule #8: Score      |
//|   Engine must be multi-asset) and snapshots the broker's trading   |
//|   constraints (point, tick value, volume step, stops level) that   |
//|   the Risk and Execution layers need.                              |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_SYMBOLPROFILE_MQH
#define CLSAGENT_SYMBOLPROFILE_MQH

#include "../Core/CLSAgent_Types.mqh"
#include "../Core/CLSAgent_Inputs.mqh"
#include "../Core/CLSAgent_Utils.mqh"

struct SSymbolProfile
{
   string               symbol;
   ENUM_CLS_ASSET_CLASS assetClass;
   int                  digits;
   double               point;
   double               tickSize;
   double               tickValue;
   double               volumeMin;
   double               volumeMax;
   double               volumeStep;
   int                  stopsLevelPoints;
   int                  freezeLevelPoints;
   int                  maxSpreadPoints;   // resolved from InpMaxSpreadPoints{Gold,Forex}
   double               minScoreToTrade;   // resolved from InpMinScoreToTrade{Gold,Forex}
   bool                 isValid;

   SSymbolProfile()
   {
      symbol            = "";
      assetClass        = CLS_ASSET_FOREX;
      digits            = 0;
      point             = 0.0;
      tickSize          = 0.0;
      tickValue         = 0.0;
      volumeMin         = 0.0;
      volumeMax         = 0.0;
      volumeStep        = 0.0;
      stopsLevelPoints  = 0;
      freezeLevelPoints = 0;
      maxSpreadPoints   = 0;
      minScoreToTrade   = 0.0;
      isValid           = false;
   }
};

SSymbolProfile g_SymbolProfile;

//+------------------------------------------------------------------+
//| Rule #8: Gold and Forex get separate profiles everywhere          |
//| downstream. Detection is name-based since brokers spell Gold      |
//| differently (XAUUSD, XAUUSDm, GOLD, ...).                         |
//+------------------------------------------------------------------+
ENUM_CLS_ASSET_CLASS CLS_ResolveAssetClass(const string symbol)
{
   string aliases[];
   const int n = CLS_SplitCsv(InpGoldAliases, aliases);

   for(int i = 0; i < n; i++)
   {
      if(StringLen(aliases[i]) > 0 && StringFind(symbol, aliases[i]) >= 0)
         return CLS_ASSET_GOLD;
   }
   return CLS_ASSET_FOREX;
}

//+------------------------------------------------------------------+
//| Populates g_SymbolProfile from the broker's current SymbolInfo.   |
//| Called once from OnInit() and refreshed once per closed bar by    |
//| the Context Engine, since brokers can change tick value/stops     |
//| level intraday (e.g. around rollover).                            |
//+------------------------------------------------------------------+
bool CLS_BuildSymbolProfile(const string symbol, SSymbolProfile &profile)
{
   profile.symbol            = symbol;
   profile.assetClass        = CLS_ResolveAssetClass(symbol);
   profile.digits            = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   profile.point             = SymbolInfoDouble(symbol, SYMBOL_POINT);
   profile.tickSize          = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   profile.tickValue         = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   profile.volumeMin         = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   profile.volumeMax         = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   profile.volumeStep        = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   profile.stopsLevelPoints  = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   profile.freezeLevelPoints = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);

   profile.maxSpreadPoints = (profile.assetClass == CLS_ASSET_GOLD)
                                 ? InpMaxSpreadPointsGold
                                 : InpMaxSpreadPointsForex;
   profile.minScoreToTrade = (profile.assetClass == CLS_ASSET_GOLD)
                                 ? InpMinScoreToTradeGold
                                 : InpMinScoreToTradeForex;

   profile.isValid = (profile.point > 0.0 && profile.tickSize > 0.0 && profile.tickValue > 0.0);

   if(!profile.isValid)
      CLS_Log(CLS_LOG_ERROR, "SymbolProfile", "Broker returned invalid point/tick data for " + symbol + ".");

   return profile.isValid;
}

#endif // CLSAGENT_SYMBOLPROFILE_MQH
