//+------------------------------------------------------------------+
//|                                          CLSAgent_ATRRegime.mqh  |
//|   CLS Agent v2.4+ - Market / ATR Volatility Regime - Part 2      |
//|                                                                    |
//|   Classifies current volatility relative to its own recent        |
//|   baseline so the Risk Engine (Part 5) can block entries during    |
//|   abnormal volatility per Rule #7.                                  |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_ATRREGIME_MQH
#define CLSAGENT_ATRREGIME_MQH

#include "../Core/CLSAgent_Types.mqh"
#include "../Core/CLSAgent_Inputs.mqh"
#include "CLSAgent_Indicators.mqh"

#define CLS_ATR_BASELINE_LOOKBACK 50

ENUM_CLS_ATR_REGIME CLS_ClassifyATRRegime(const double currentATR, const double avgATR)
{
   if(avgATR <= 0.0)
      return CLS_ATR_REGIME_NORMAL;

   const double ratio = currentATR / avgATR;

   if(ratio >= InpATRRegimeExtremeMult)
      return CLS_ATR_REGIME_EXTREME;
   if(ratio >= InpATRRegimeHighMult)
      return CLS_ATR_REGIME_HIGH;
   if(ratio <= (1.0 / InpATRRegimeHighMult))
      return CLS_ATR_REGIME_LOW;

   return CLS_ATR_REGIME_NORMAL;
}

//+------------------------------------------------------------------+
//| Reads the current ATR plus a rolling baseline average and returns  |
//| both the classified regime and the raw ATR value (the latter is    |
//| also used downstream for ATR-based stop placement in Part 3/7).    |
//+------------------------------------------------------------------+
bool CLS_GetATRRegimeNow(ENUM_CLS_ATR_REGIME &regimeOut, double &atrValueOut)
{
   double series[];
   if(!CLS_GetATRSeries(0, CLS_ATR_BASELINE_LOOKBACK, series))
      return false;

   atrValueOut = series[0];

   double sum = 0.0;
   for(int i = 0; i < CLS_ATR_BASELINE_LOOKBACK; i++)
      sum += series[i];
   const double avg = sum / CLS_ATR_BASELINE_LOOKBACK;

   regimeOut = CLS_ClassifyATRRegime(atrValueOut, avg);
   return true;
}

bool CLS_IsATRRegimeTradeable(const ENUM_CLS_ATR_REGIME regime)
{
   // Rule #7: extreme volatility always blocks new entries. LOW/NORMAL/HIGH
   // are still tradeable - the Score Engine (Part 4) penalizes HIGH instead
   // of hard-blocking it, since some setups (e.g. BMS Continuation) want it.
   return regime != CLS_ATR_REGIME_EXTREME;
}

#endif // CLSAGENT_ATRREGIME_MQH
