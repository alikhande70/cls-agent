//+------------------------------------------------------------------+
//|                                         CLSAgent_PartialExit.mqh |
//|   CLS Agent v2.4+ - Execution / Partial Exit - Part 7            |
//|                                                                    |
//|   Closes InpPartialExitPercent of a position once it reaches        |
//|   InpPartialExitTriggerR, exactly once per ticket. There is no way   |
//|   to infer "already done" from broker data alone (the position's     |
//|   own volume shrinks either way), so this keeps a narrow, ephemeral  |
//|   one-shot-guard cache here - the only exception in the project to    |
//|   the "always read live broker state, never a separate tally"        |
//|   philosophy (contrast CLSAgent_BasketRisk.mqh). Lost on EA restart;  |
//|   the only consequence is a position being partial-exited a second    |
//|   time after a restart, not a risk breach. Part 8 (Memory/Journal)    |
//|   adds real persistence later.                                        |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_PARTIALEXIT_MQH
#define CLSAGENT_PARTIALEXIT_MQH

#include "../Core/CLSAgent_Inputs.mqh"
#include "../Core/CLSAgent_Utils.mqh"
#include "../Risk/CLSAgent_LotCalculator.mqh"
#include "CLSAgent_OrderSender.mqh"

ulong g_PartialExitedTickets[];

bool CLS_PartialExit_AlreadyDone(const ulong ticket)
{
   const int n = ArraySize(g_PartialExitedTickets);
   for(int i = 0; i < n; i++)
      if(g_PartialExitedTickets[i] == ticket)
         return true;
   return false;
}

void CLS_PartialExit_MarkDone(const ulong ticket)
{
   const int n = ArraySize(g_PartialExitedTickets);
   ArrayResize(g_PartialExitedTickets, n + 1);
   g_PartialExitedTickets[n] = ticket;
}

//+------------------------------------------------------------------+
//| Drops any cached ticket that is no longer an open position, so the  |
//| array does not grow without bound over the life of the chart.       |
//+------------------------------------------------------------------+
void CLS_PartialExit_Prune(const ulong &liveTickets[], const int liveCount)
{
   ulong kept[];
   ArrayResize(kept, 0);

   const int n = ArraySize(g_PartialExitedTickets);
   for(int i = 0; i < n; i++)
   {
      bool stillLive = false;
      for(int j = 0; j < liveCount; j++)
      {
         if(liveTickets[j] == g_PartialExitedTickets[i])
         {
            stillLive = true;
            break;
         }
      }
      if(stillLive)
      {
         const int k = ArraySize(kept);
         ArrayResize(kept, k + 1);
         kept[k] = g_PartialExitedTickets[i];
      }
   }

   ArrayResize(g_PartialExitedTickets, ArraySize(kept));
   for(int i = 0; i < ArraySize(kept); i++)
      g_PartialExitedTickets[i] = kept[i];
}

//+------------------------------------------------------------------+
//| Returns false without sending anything if already done this        |
//| ticket, or if the split would leave a zero-volume leg on either     |
//| side (broker volume-step rounding made the split degenerate).       |
//+------------------------------------------------------------------+
bool CLS_TryPartialExit(const ulong ticket, const string symbol, const ENUM_POSITION_TYPE posType, const double volume)
{
   if(CLS_PartialExit_AlreadyDone(ticket))
      return false;

   const double closeVolume = CLS_NormalizeVolume(volume * (InpPartialExitPercent / 100.0));
   const double remaining   = CLS_NormalizeVolume(volume - closeVolume);
   if(closeVolume <= 0.0 || remaining <= 0.0)
      return false;

   const bool closed = CLS_ClosePositionPartial(ticket, symbol, posType, closeVolume);
   if(closed)
      CLS_PartialExit_MarkDone(ticket);

   CLS_Log(closed ? CLS_LOG_INFO : CLS_LOG_WARNING, "PartialExit", StringFormat(
      "ticket=%I64u close=%.2f remaining=%.2f sent=%s", ticket, closeVolume, remaining, (closed ? "true" : "false")));

   return closed;
}

#endif // CLSAGENT_PARTIALEXIT_MQH
