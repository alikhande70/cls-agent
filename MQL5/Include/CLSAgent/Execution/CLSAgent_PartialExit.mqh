//+------------------------------------------------------------------+
//|                                         CLSAgent_PartialExit.mqh |
//|   CLS Agent v2.4+ - Execution / Partial Exit - Part 7/10         |
//|                                                                    |
//|   Closes InpPartialExitPercent of a position once it reaches        |
//|   InpPartialExitTriggerR, exactly once per ticket. There is no way   |
//|   to infer "already done" from broker data alone (the position's     |
//|   own volume shrinks either way), so this keeps a narrow one-shot-     |
//|   guard cache here - the only exception in the project to the          |
//|   "always read live broker state, never a separate tally"              |
//|   philosophy (contrast CLSAgent_BasketRisk.mqh). The cache is mirrored   |
//|   to CLS_FILES_STATE_DIR on every change (Part 10) and reloaded once      |
//|   in OnInit(), so an EA restart mid-trade still remembers which open       |
//|   tickets were already partial-exited instead of doing it twice.            |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_PARTIALEXIT_MQH
#define CLSAGENT_PARTIALEXIT_MQH

#include "../Core/CLSAgent_Constants.mqh"
#include "../Core/CLSAgent_Inputs.mqh"
#include "../Core/CLSAgent_Utils.mqh"
#include "../Risk/CLSAgent_LotCalculator.mqh"
#include "CLSAgent_OrderSender.mqh"

ulong g_PartialExitedTickets[];

//+------------------------------------------------------------------+
//| Overwrites the state file with the current in-memory cache - a      |
//| point-in-time snapshot (FILE_WRITE alone truncates), same convention  |
//| as Part 9's CLS_Report_ExportPerformanceCSV(). Unlike that export,      |
//| this is functional state rather than a log mirror, so it is NOT gated   |
//| by InpLogToFile.                                                          |
//+------------------------------------------------------------------+
void CLS_PartialExit_SaveState()
{
   const string path   = CLS_FILES_STATE_DIR + "partial_exits.state";
   const int    handle = FileOpen(path, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      CLS_Log(CLS_LOG_ERROR, "PartialExit", StringFormat("Failed to save state to %s, error=%d.", path, GetLastError()));
      return;
   }

   const int n = ArraySize(g_PartialExitedTickets);
   for(int i = 0; i < n; i++)
      FileWrite(handle, (string)g_PartialExitedTickets[i]);

   FileClose(handle);
}

//+------------------------------------------------------------------+
//| Call once from OnInit() - repopulates the cache from the previous     |
//| run's snapshot so a restart mid-trade does not partial-exit a          |
//| position a second time. Silent no-op (empty cache) if the file does     |
//| not exist yet, e.g. first-ever run.                                       |
//+------------------------------------------------------------------+
void CLS_PartialExit_LoadState()
{
   ArrayResize(g_PartialExitedTickets, 0);

   const string path = CLS_FILES_STATE_DIR + "partial_exits.state";
   if(!FileIsExist(path))
      return;

   const int handle = FileOpen(path, FILE_READ | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
      return;

   while(!FileIsEnding(handle))
   {
      const string line = FileReadString(handle);
      if(StringLen(line) == 0)
         continue;

      const int n = ArraySize(g_PartialExitedTickets);
      ArrayResize(g_PartialExitedTickets, n + 1);
      g_PartialExitedTickets[n] = (ulong)StringToInteger(line);
   }

   FileClose(handle);
   CLS_Log(CLS_LOG_INFO, "PartialExit", StringFormat("Restored %d partial-exit ticket(s) from %s.", ArraySize(g_PartialExitedTickets), path));
}

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
   CLS_PartialExit_SaveState();
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

   const bool changed = (ArraySize(kept) != n);

   ArrayResize(g_PartialExitedTickets, ArraySize(kept));
   for(int i = 0; i < ArraySize(kept); i++)
      g_PartialExitedTickets[i] = kept[i];

   if(changed)
      CLS_PartialExit_SaveState();
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
