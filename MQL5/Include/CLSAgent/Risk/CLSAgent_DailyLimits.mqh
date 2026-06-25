//+------------------------------------------------------------------+
//|                                        CLSAgent_DailyLimits.mqh  |
//|   CLS Agent v2.4+ - Risk / Daily Limits - Part 5                 |
//|                                                                    |
//|   Rule #7: DailyLoss must be checked before every entry. The      |
//|   baseline equity is captured once per broker day by               |
//|   CLS_State_RolloverDayIfNeeded() (Part 1/Core); this module only  |
//|   compares current equity against that baseline.                   |
//|                                                                    |
//|   This module only reports the boolean - it takes no action.      |
//|   Two separate call sites act on it: RiskEngine.mqh blocks new      |
//|   entries (CLS_REJECT_DAILY_LOSS) once per signal, and CLSAgent.mq5's |
//|   OnTick() additionally calls CLS_FlattenAllPositions() every tick    |
//|   once this is true, closing any already-open exposure immediately    |
//|   rather than leaving it to run unmanaged for the rest of the day.     |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_DAILYLIMITS_MQH
#define CLSAGENT_DAILYLIMITS_MQH

#include "../Core/CLSAgent_Inputs.mqh"
#include "../Core/CLSAgent_State.mqh"

double CLS_CurrentDailyLossPercent()
{
   if(g_State.dailyStartEquity <= 0.0)
      return 0.0;

   const double equityNow   = AccountInfoDouble(ACCOUNT_EQUITY);
   const double lossPercent = (g_State.dailyStartEquity - equityNow) / g_State.dailyStartEquity * 100.0;
   return MathMax(0.0, lossPercent);
}

bool CLS_IsDailyLossLimitHit()
{
   return CLS_CurrentDailyLossPercent() >= InpMaxDailyLossPercent;
}

#endif // CLSAGENT_DAILYLIMITS_MQH
