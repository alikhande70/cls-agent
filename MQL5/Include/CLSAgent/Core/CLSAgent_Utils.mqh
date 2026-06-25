//+------------------------------------------------------------------+
//|                                            CLSAgent_Utils.mqh    |
//|   CLS Agent v2.4+ - Decision-Safe Contextual Liquidity Scalping  |
//|   Core / Utilities - Part 1                                      |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_UTILS_MQH
#define CLSAGENT_UTILS_MQH

#include "CLSAgent_Types.mqh"
#include "CLSAgent_Constants.mqh"

// Minimum severity that CLS_Log will actually print. Set from InpLogLevel
// in OnInit(); declared here (not in State.mqh) because logging must work
// even before CLS_State_Init() runs.
int g_LogMinLevel = CLS_LOG_INFO;

string CLS_LogLevelToString(const ENUM_CLS_LOG_LEVEL level)
{
   switch(level)
   {
      case CLS_LOG_DEBUG:   return "DEBUG";
      case CLS_LOG_INFO:    return "INFO";
      case CLS_LOG_WARNING: return "WARN";
      case CLS_LOG_ERROR:   return "ERROR";
   }
   return "?";
}

//+------------------------------------------------------------------+
//| Single funnel for all EA console logging so every later module    |
//| (Journal in Part 8, Reporting in Part 9) can format consistently   |
//| and log-level filtering stays centralized in one place.            |
//+------------------------------------------------------------------+
void CLS_Log(const ENUM_CLS_LOG_LEVEL level, const string tag, const string message)
{
   if((int)level < g_LogMinLevel)
      return;

   PrintFormat("[%s][%s][%s] %s", CLS_AGENT_NAME, CLS_LogLevelToString(level), tag, message);
}

string CLS_RejectReasonToString(const ENUM_CLS_REJECT_REASON reason)
{
   switch(reason)
   {
      case CLS_REJECT_NONE:            return "NONE";
      case CLS_REJECT_SPREAD:          return "SPREAD_TOO_WIDE";
      case CLS_REJECT_SESSION:         return "OUTSIDE_SESSION";
      case CLS_REJECT_ATR_REGIME:      return "ATR_REGIME_BLOCKED";
      case CLS_REJECT_DAILY_LOSS:      return "DAILY_LOSS_LIMIT";
      case CLS_REJECT_SCORE_LOW:       return "SCORE_BELOW_MIN";
      case CLS_REJECT_BASKET_FULL:     return "BASKET_FULL";
      case CLS_REJECT_LOSING_BASKET:   return "NO_ADD_TO_LOSING_BASKET";
      case CLS_REJECT_NEWS:            return "NEWS_GUARD";
      case CLS_REJECT_PERMISSION:      return "PERMISSION_DENIED";
      case CLS_REJECT_UNCONFIRMED_BAR: return "BAR_NOT_CLOSED";
      case CLS_REJECT_LOSS_STREAK:     return "LOSS_STREAK_PROTECTION";
      case CLS_REJECT_OTHER:           return "OTHER";
   }
   return "UNKNOWN";
}

string CLS_DirectionToString(const ENUM_CLS_DIRECTION dir)
{
   if(dir == CLS_DIR_BUY)  return "BUY";
   if(dir == CLS_DIR_SELL) return "SELL";
   return "NONE";
}

bool CLS_IsDoubleEqual(const double a, const double b)
{
   return MathAbs(a - b) < CLS_PRICE_EPSILON;
}

//+------------------------------------------------------------------+
//| Splits a comma-separated alias list ("XAUUSD,XAUUSDm,GOLD") into   |
//| trimmed tokens. Used today by CLSAgent.mq5 to auto-detect Gold vs  |
//| Forex from the chart symbol, and later by SymbolProfile (Part 2)   |
//| to recognize broker-specific spellings of the same instrument.     |
//+------------------------------------------------------------------+
int CLS_SplitCsv(const string csv, string &outTokens[])
{
   string raw[];
   const int count = StringSplit(csv, ',', raw);
   ArrayResize(outTokens, count);

   for(int i = 0; i < count; i++)
   {
      string token = raw[i];
      StringTrimLeft(token);
      StringTrimRight(token);
      outTokens[i] = token;
   }
   return count;
}

#endif // CLSAGENT_UTILS_MQH
