//+------------------------------------------------------------------+
//|                                          CLSAgent_NewsGuard.mqh  |
//|   CLS Agent v2.4+ - Risk / News Guard - Part 5                   |
//|                                                                    |
//|   v1 News Guard is manual/input-based only (no economic-calendar   |
//|   integration). The user pastes high-impact windows as             |
//|   "YYYY.MM.DD HH:MM-HH:MM;YYYY.MM.DD HH:MM-HH:MM;...". Rule #7      |
//|   treats a match as a hard block, same severity as spread/session. |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_NEWSGUARD_MQH
#define CLSAGENT_NEWSGUARD_MQH

#include "../Core/CLSAgent_Inputs.mqh"
#include "../Core/CLSAgent_Utils.mqh"

bool CLS_IsInNewsWindow(const datetime now)
{
   if(!InpNewsGuardEnabled || StringLen(InpNewsBlockWindowsRaw) == 0)
      return false;

   string windows[];
   const int windowCount = StringSplit(InpNewsBlockWindowsRaw, ';', windows);

   for(int i = 0; i < windowCount; i++)
   {
      string entry = windows[i];
      StringTrimLeft(entry);
      StringTrimRight(entry);
      if(StringLen(entry) == 0)
         continue;

      string dateAndRange[];
      if(StringSplit(entry, ' ', dateAndRange) != 2)
      {
         CLS_Log(CLS_LOG_WARNING, "NewsGuard", "Malformed window (expected 'YYYY.MM.DD HH:MM-HH:MM'): " + entry);
         continue;
      }

      string range[];
      if(StringSplit(dateAndRange[1], '-', range) != 2)
      {
         CLS_Log(CLS_LOG_WARNING, "NewsGuard", "Malformed time range in window: " + entry);
         continue;
      }

      const datetime windowStart = StringToTime(dateAndRange[0] + " " + range[0]);
      datetime       windowEnd   = StringToTime(dateAndRange[0] + " " + range[1]);
      if(windowEnd <= windowStart)
         windowEnd += 86400; // window crosses midnight

      if(now >= windowStart && now < windowEnd)
         return true;
   }

   return false;
}

#endif // CLSAGENT_NEWSGUARD_MQH
