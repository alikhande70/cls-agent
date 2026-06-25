//+------------------------------------------------------------------+
//|                                           CLSAgent_Trailing.mqh  |
//|   CLS Agent v2.4+ - Execution / Trailing Stop - Part 7           |
//|                                                                    |
//|   Pure calculation, no broker calls - returns a candidate SL only   |
//|   when it strictly improves on the current one by at least          |
//|   InpTrailingStopStepPoints, so PositionManager only ever sends a   |
//|   modify when it is worth the round trip.                           |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_TRAILING_MQH
#define CLSAGENT_TRAILING_MQH

#include "../Core/CLSAgent_Types.mqh"
#include "../Core/CLSAgent_Inputs.mqh"
#include "../Market/CLSAgent_SymbolProfile.mqh"

//+------------------------------------------------------------------+
//| Returns false if there is nothing worth sending: trail distance     |
//| degenerate, candidate does not improve on currentSL, or the          |
//| improvement is smaller than InpTrailingStopStepPoints.               |
//+------------------------------------------------------------------+
bool CLS_ComputeTrailingStop(const ENUM_POSITION_TYPE posType, const double currentPrice, const double currentSL,
                              const double atrValue, double &outNewSL)
{
   const double trailDistance = atrValue * InpTrailingStopATRMultiplier;
   if(trailDistance <= 0.0)
      return false;

   double candidate;
   if(posType == POSITION_TYPE_BUY)
   {
      candidate = currentPrice - trailDistance;
      if(currentSL > 0.0 && candidate <= currentSL)
         return false;
   }
   else
   {
      candidate = currentPrice + trailDistance;
      if(currentSL > 0.0 && candidate >= currentSL)
         return false;
   }

   const double minStep = InpTrailingStopStepPoints * g_SymbolProfile.point;
   if(currentSL > 0.0 && MathAbs(candidate - currentSL) < minStep)
      return false;

   outNewSL = candidate;
   return true;
}

#endif // CLSAGENT_TRAILING_MQH
