//+------------------------------------------------------------------+
//|                                      CLSAgent_LotCalculator.mqh  |
//|   CLS Agent v2.4+ - Risk / Lot Calculator - Part 5               |
//|                                                                    |
//|   Rule #3: sizing is driven by TotalBasketRisk (the caller passes  |
//|   its own per-order share of it), never a flat RiskPerOrder input. |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_LOTCALCULATOR_MQH
#define CLSAGENT_LOTCALCULATOR_MQH

#include "../Core/CLSAgent_Constants.mqh"
#include "../Market/CLSAgent_SymbolProfile.mqh"

//+------------------------------------------------------------------+
//| Rounds down to the nearest broker volume step, never up - sizing   |
//| must never exceed the requested risk, only undershoot it. Returns  |
//| 0.0 if the rounded volume would still fall under the broker's       |
//| minimum (too small to place at all).                                |
//+------------------------------------------------------------------+
double CLS_NormalizeVolume(const double rawVolume)
{
   if(g_SymbolProfile.volumeStep <= 0.0)
      return 0.0;

   const double steps  = MathFloor(rawVolume / g_SymbolProfile.volumeStep + CLS_PRICE_EPSILON);
   double       volume = MathMax(0.0, steps * g_SymbolProfile.volumeStep);

   if(volume > 0.0 && volume < g_SymbolProfile.volumeMin)
      volume = 0.0;
   if(g_SymbolProfile.volumeMax > 0.0)
      volume = MathMin(volume, g_SymbolProfile.volumeMax);

   return volume;
}

//+------------------------------------------------------------------+
//| Returns 0.0 if the stop distance or broker data make sizing        |
//| impossible - the caller (Risk Engine) must reject the signal then. |
//+------------------------------------------------------------------+
double CLS_CalculateLotSize(const double entryPrice, const double stopLoss, const double riskPercent)
{
   const double stopDistance = MathAbs(entryPrice - stopLoss);
   if(stopDistance <= CLS_PRICE_EPSILON || g_SymbolProfile.tickSize <= 0.0 || g_SymbolProfile.tickValue <= 0.0)
      return 0.0;

   const double equity     = AccountInfoDouble(ACCOUNT_EQUITY);
   const double riskAmount = equity * (riskPercent / 100.0);
   const double lossPerLot = (stopDistance / g_SymbolProfile.tickSize) * g_SymbolProfile.tickValue;
   if(lossPerLot <= 0.0)
      return 0.0;

   return CLS_NormalizeVolume(riskAmount / lossPerLot);
}

#endif // CLSAGENT_LOTCALCULATOR_MQH
