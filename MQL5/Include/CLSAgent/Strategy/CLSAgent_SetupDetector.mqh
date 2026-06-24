//+------------------------------------------------------------------+
//|                                     CLSAgent_SetupDetector.mqh   |
//|   CLS Agent v2.4+ - Strategy / Setup Detector - Part 3           |
//|                                                                    |
//|   Single entry point the EA shell calls once per closed bar.       |
//|   Tries Setups A-D in a fixed priority order and stops at the      |
//|   first valid signal - only one setup may fire per bar, since the  |
//|   Score/Risk/Basket stages downstream assume a single candidate.   |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_SETUPDETECTOR_MQH
#define CLSAGENT_SETUPDETECTOR_MQH

#include "../Core/CLSAgent_Types.mqh"
#include "CLSAgent_SetupContext.mqh"
#include "CLSAgent_SetupA_AsianSweep.mqh"
#include "CLSAgent_SetupB_DailyHunt.mqh"
#include "CLSAgent_SetupC_FVGFill.mqh"
#include "CLSAgent_SetupD_BMSContinuation.mqh"

bool CLS_DetectSetups(const SSetupContext &ctx, SSetupSignal &signalOut)
{
   signalOut = SSetupSignal(); // reset to safe defaults (isValid=false)

   if(!ctx.isContextValid)
      return false;

   if(CLS_DetectSetupA_AsianSweep(ctx, signalOut))      return true;
   if(CLS_DetectSetupB_DailyHunt(ctx, signalOut))       return true;
   if(CLS_DetectSetupC_FVGFill(ctx, signalOut))         return true;
   if(CLS_DetectSetupD_BMSContinuation(ctx, signalOut)) return true;

   return false;
}

#endif // CLSAGENT_SETUPDETECTOR_MQH
