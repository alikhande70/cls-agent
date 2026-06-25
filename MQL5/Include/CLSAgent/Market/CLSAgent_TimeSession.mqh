//+------------------------------------------------------------------+
//|                                       CLSAgent_TimeSession.mqh   |
//|   CLS Agent v2.4+ - Market / Time & Session - Part 2             |
//|                                                                    |
//|   Classifies the current broker-time hour into a trading session  |
//|   so the Risk Engine (Part 5) can enforce Rule #7 (Session must    |
//|   be checked before entry).                                        |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_TIMESESSION_MQH
#define CLSAGENT_TIMESESSION_MQH

#include "../Core/CLSAgent_Types.mqh"
#include "../Core/CLSAgent_Inputs.mqh"

//+------------------------------------------------------------------+
//| True if hour falls in [start,end). Handles ranges that wrap past   |
//| midnight (e.g. start=22, end=4) so session hours can be defined    |
//| however the broker's clock lines up with London/NY/Asia.           |
//+------------------------------------------------------------------+
bool CLS_HourInRange(const int hour, const int startHour, const int endHour)
{
   if(startHour == endHour)
      return false; // zero-width window, never tradeable

   if(startHour < endHour)
      return (hour >= startHour && hour < endHour);

   // wraps past midnight
   return (hour >= startHour || hour < endHour);
}

//+------------------------------------------------------------------+
//| Returns the session for a given broker-time timestamp. London+NY  |
//| overlap takes priority since it is the highest-liquidity window.  |
//+------------------------------------------------------------------+
ENUM_CLS_SESSION CLS_GetSessionForTime(const datetime brokerTime)
{
   MqlDateTime dt;
   TimeToStruct(brokerTime, dt);
   const int hour = dt.hour;

   const bool asian   = InpUseAsianSession   && CLS_HourInRange(hour, InpSessionAsianStartHour,   InpSessionAsianEndHour);
   const bool london  = InpUseLondonSession  && CLS_HourInRange(hour, InpSessionLondonStartHour,  InpSessionLondonEndHour);
   const bool newYork = InpUseNewYorkSession && CLS_HourInRange(hour, InpSessionNewYorkStartHour, InpSessionNewYorkEndHour);

   if(london && newYork) return CLS_SESSION_OVERLAP;
   if(london)            return CLS_SESSION_LONDON;
   if(newYork)            return CLS_SESSION_NEWYORK;
   if(asian)              return CLS_SESSION_ASIAN;
   return CLS_SESSION_OFF;
}

ENUM_CLS_SESSION CLS_GetCurrentSession()
{
   return CLS_GetSessionForTime(TimeCurrent());
}

bool CLS_IsSessionTradeable(const ENUM_CLS_SESSION session)
{
   return session != CLS_SESSION_OFF;
}

#endif // CLSAGENT_TIMESESSION_MQH
