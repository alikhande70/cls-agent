//+------------------------------------------------------------------+
//|                                        CLSAgent_Indicators.mqh  |
//|   CLS Agent v2.4+ - Market / Indicator Handles - Part 2          |
//|                                                                    |
//|   Owns every indicator handle used by the EA. Single-symbol-per-  |
//|   chart in v1, so one handle per indicator is enough.              |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_INDICATORS_MQH
#define CLSAGENT_INDICATORS_MQH

#include "../Core/CLSAgent_Inputs.mqh"
#include "../Core/CLSAgent_Utils.mqh"

int g_HandleATR = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Call once from OnInit(), after the symbol is known.                |
//+------------------------------------------------------------------+
bool CLS_Indicators_Init(const string symbol)
{
   g_HandleATR = iATR(symbol, InpATRTimeframe, InpATRPeriod);
   if(g_HandleATR == INVALID_HANDLE)
   {
      CLS_Log(CLS_LOG_ERROR, "Indicators", "Failed to create ATR handle, error=" + (string)GetLastError());
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Call once from OnDeinit().                                        |
//+------------------------------------------------------------------+
void CLS_Indicators_Deinit()
{
   if(g_HandleATR != INVALID_HANDLE)
      IndicatorRelease(g_HandleATR);
   g_HandleATR = INVALID_HANDLE;
}

bool CLS_Indicators_IsReady()
{
   return g_HandleATR != INVALID_HANDLE && BarsCalculated(g_HandleATR) > 0;
}

//+------------------------------------------------------------------+
//| Single ATR value at the given shift (0 = current/last closed bar  |
//| on InpATRTimeframe, per CopyBuffer semantics).                     |
//+------------------------------------------------------------------+
bool CLS_GetATR(const int shift, double &value)
{
   double buf[];
   if(CopyBuffer(g_HandleATR, 0, shift, 1, buf) != 1)
      return false;
   value = buf[0];
   return true;
}

//+------------------------------------------------------------------+
//| ATR series, most recent first (index 0 = shift bars back).        |
//+------------------------------------------------------------------+
bool CLS_GetATRSeries(const int shift, const int count, double &values[])
{
   ArraySetAsSeries(values, true);
   return CopyBuffer(g_HandleATR, 0, shift, count, values) == count;
}

#endif // CLSAGENT_INDICATORS_MQH
