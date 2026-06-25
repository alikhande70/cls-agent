//+------------------------------------------------------------------+
//|                                        CLSAgent_DebugPanel.mqh   |
//|   CLS Agent v2.4+ - Reports / Debug Panel - Part 9               |
//|                                                                    |
//|   Cheap on-chart visibility into what the deterministic pipeline    |
//|   is doing right now - this never feeds back into any decision,     |
//|   it only renders state that already exists elsewhere (Context,      |
//|   BasketRisk's live scan, PerformanceStats' running totals). Reads    |
//|   account/position state fresh on every render rather than caching     |
//|   it, the same "always read live broker state" rule the rest of the    |
//|   project follows - only the last-built SSetupContext (bar-cadence      |
//|   fields like session/ATR/spread) is cached, since OnTimer() needs to     |
//|   redraw between bar closes when nothing new has actually been built.       |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_DEBUGPANEL_MQH
#define CLSAGENT_DEBUGPANEL_MQH

#include "../Core/CLSAgent_Types.mqh"
#include "../Core/CLSAgent_Constants.mqh"
#include "../Core/CLSAgent_Inputs.mqh"
#include "../Core/CLSAgent_State.mqh"
#include "../Core/CLSAgent_Utils.mqh"
#include "../Risk/CLSAgent_BasketRisk.mqh"
#include "../Memory/CLSAgent_PerformanceStats.mqh"

SSetupContext g_DebugPanelLastContext;

string CLS_DebugPanel_BasketLine(const string symbol, const ENUM_CLS_DIRECTION direction)
{
   SBasketInfo basket;
   const bool  has = CLS_ScanCurrentBasket(symbol, direction, basket);
   if(!has)
      return StringFormat("  %s: flat", CLS_DirectionToString(direction));

   return StringFormat("  %s: orders=%d lots=%.2f avgEntry=%.5f %s risk=%.2f%%",
      CLS_DirectionToString(direction), basket.ordersCount, basket.totalLots, basket.averageEntry,
      (basket.isLosing ? "LOSING" : "OK"), basket.totalRiskPercent);
}

string CLS_DebugPanel_StatsLine(const string label, const SPerformanceStats &s)
{
   return StringFormat("  %s: trades=%d winRate=%.1f%% PF=%.2f gross+=%.2f gross-=%.2f",
      label, s.tradesClosed, CLS_PerformanceStats_WinRate(s), CLS_PerformanceStats_ProfitFactor(s),
      s.grossProfit, s.grossLoss);
}

void CLS_DebugPanel_Render()
{
   if(!InpShowDebugPanel)
      return;

   const SSetupContext ctx = g_DebugPanelLastContext;

   const double equity      = AccountInfoDouble(ACCOUNT_EQUITY);
   const double balance     = AccountInfoDouble(ACCOUNT_BALANCE);
   const double dailyPnl    = equity - g_State.dailyStartEquity;
   const double dailyPnlPct = (g_State.dailyStartEquity > 0.0) ? (100.0 * dailyPnl / g_State.dailyStartEquity) : 0.0;

   string text = "";
   text += StringFormat("%s v%s | %s | Mode=%s AutoTrade=%s TradingAllowed=%s\n",
      CLS_AGENT_NAME, CLS_AGENT_VERSION, ctx.symbol, EnumToString(InpMode),
      (InpAutoTrade ? "true" : "false"), (g_State.tradingAllowedByMode ? "true" : "false"));
   text += StringFormat("Bar=%s Session=%s(%s) ATR=%s(%.5f,%s) Spread=%.1f(%s)\n",
      TimeToString(ctx.barTime, TIME_DATE | TIME_MINUTES),
      EnumToString(ctx.session), (ctx.sessionAllowed ? "OK" : "BLOCKED"),
      EnumToString(ctx.atrRegime), ctx.atrValue, (ctx.atrRegimeAllowed ? "OK" : "BLOCKED"),
      ctx.spreadPoints, (ctx.spreadAllowed ? "OK" : "BLOCKED"));
   text += StringFormat("Equity=%.2f Balance=%.2f DailyP/L=%.2f(%.2f%%) MaxDailyLoss=%.2f%%\n",
      equity, balance, dailyPnl, dailyPnlPct, InpMaxDailyLossPercent);
   text += "Baskets:\n";
   text += CLS_DebugPanel_BasketLine(ctx.symbol, CLS_DIR_BUY) + "\n";
   text += CLS_DebugPanel_BasketLine(ctx.symbol, CLS_DIR_SELL) + "\n";
   text += "Performance:\n";
   text += CLS_DebugPanel_StatsLine("ALL", g_PerfStats[0]) + "\n";
   text += CLS_DebugPanel_StatsLine("A", g_PerfStats[(int)CLS_SETUP_A_ASIAN_SWEEP]) + "\n";
   text += CLS_DebugPanel_StatsLine("B", g_PerfStats[(int)CLS_SETUP_B_DAILY_HUNT]) + "\n";
   text += CLS_DebugPanel_StatsLine("C", g_PerfStats[(int)CLS_SETUP_C_FVG_FILL]) + "\n";
   text += CLS_DebugPanel_StatsLine("D", g_PerfStats[(int)CLS_SETUP_D_BMS_CONTINUATION]);

   Comment(text);
}

//+------------------------------------------------------------------+
//| Call once per closed bar with the freshly-built context - the only   |
//| write to g_DebugPanelLastContext. OnTimer() only ever re-renders      |
//| from whatever was cached here last, it never builds its own context.  |
//+------------------------------------------------------------------+
void CLS_DebugPanel_Update(const SSetupContext &ctx)
{
   g_DebugPanelLastContext = ctx;
   CLS_DebugPanel_Render();
}

//+------------------------------------------------------------------+
//| Call from OnTimer() to keep live fields (equity/basket P&L) fresh    |
//| between bar closes, without waiting for the next bar to redraw.      |
//+------------------------------------------------------------------+
void CLS_DebugPanel_Refresh()
{
   CLS_DebugPanel_Render();
}

void CLS_DebugPanel_Clear()
{
   Comment("");
}

#endif // CLSAGENT_DEBUGPANEL_MQH
