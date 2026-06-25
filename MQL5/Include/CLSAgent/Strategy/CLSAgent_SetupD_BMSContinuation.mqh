//+------------------------------------------------------------------+
//|                            CLSAgent_SetupD_BMSContinuation.mqh   |
//|   CLS Agent v2.4+ - Strategy / Setup D - Break-of-Market-         |
//|   Structure Continuation - Part 3                                |
//|                                                                    |
//|   Two-phase, stateful setup: (1) a closed bar breaks a recent      |
//|   fractal swing with a strong body -> arm; (2) on a later closed   |
//|   bar, a candle back in the break direction while price still      |
//|   holds beyond the broken level -> fire the continuation entry.    |
//|   Single-symbol-per-chart in v1, so one static state is sufficient |
//|   (see Multi-Symbol Manager limitation noted in Part 1).           |
//|                                                                    |
//|   Armed state is mirrored to CLS_FILES_STATE_DIR on every change   |
//|   and reloaded once in OnInit() (same restart-safety convention as |
//|   CLSAgent_PartialExit.mqh's ticket cache), so an EA restart while  |
//|   armed and waiting for a pullback does not silently lose it.      |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_SETUPD_BMSCONTINUATION_MQH
#define CLSAGENT_SETUPD_BMSCONTINUATION_MQH

#include "../Core/CLSAgent_Constants.mqh"
#include "../Core/CLSAgent_Types.mqh"
#include "../Core/CLSAgent_Inputs.mqh"
#include "../Core/CLSAgent_Utils.mqh"
#include "CLSAgent_SetupContext.mqh"

#define CLS_BMS_MAX_PULLBACK_WAIT_BARS 6

struct SBMSState
{
   bool                armed;
   ENUM_CLS_DIRECTION  direction;
   double              breakLevel;
   double              breakBodyStrength; // 0..1, breakout candle's body/ATR ratio - reused as rawStrength when the pullback fires
   int                 barsSinceBreak;

   SBMSState()
   {
      armed             = false;
      direction         = CLS_DIR_NONE;
      breakLevel        = 0.0;
      breakBodyStrength = 0.0;
      barsSinceBreak    = 0;
   }
};

SBMSState g_BMSState;

//+------------------------------------------------------------------+
//| Overwrites the state file with the current armed state - a         |
//| point-in-time snapshot, same FILE_WRITE convention as               |
//| CLSAgent_PartialExit.mqh's save. Called after every mutation of      |
//| g_BMSState so the on-disk copy never lags the in-memory one.          |
//+------------------------------------------------------------------+
void CLS_SetupD_SaveState()
{
   const string path   = CLS_FILES_STATE_DIR + "setup_d_bms.state";
   const int    handle = FileOpen(path, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      CLS_Log(CLS_LOG_ERROR, "SetupD", StringFormat("Failed to save state to %s, error=%d.", path, GetLastError()));
      return;
   }

   FileWrite(handle, (string)(g_BMSState.armed ? 1 : 0));
   FileWrite(handle, (string)(int)g_BMSState.direction);
   FileWrite(handle, DoubleToString(g_BMSState.breakLevel, 10));
   FileWrite(handle, DoubleToString(g_BMSState.breakBodyStrength, 10));
   FileWrite(handle, (string)g_BMSState.barsSinceBreak);

   FileClose(handle);
}

//+------------------------------------------------------------------+
//| Call once from OnInit() - repopulates g_BMSState from the previous   |
//| run's snapshot so a restart while armed and waiting for a pullback    |
//| does not silently drop back to "not armed." Silent no-op (defaults)    |
//| if the file does not exist yet, e.g. first-ever run.                     |
//+------------------------------------------------------------------+
void CLS_SetupD_LoadState()
{
   g_BMSState = SBMSState();

   const string path = CLS_FILES_STATE_DIR + "setup_d_bms.state";
   if(!FileIsExist(path))
      return;

   const int handle = FileOpen(path, FILE_READ | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
      return;

   if(!FileIsEnding(handle)) g_BMSState.armed             = (StringToInteger(FileReadString(handle)) != 0);
   if(!FileIsEnding(handle)) g_BMSState.direction         = (ENUM_CLS_DIRECTION)StringToInteger(FileReadString(handle));
   if(!FileIsEnding(handle)) g_BMSState.breakLevel        = StringToDouble(FileReadString(handle));
   if(!FileIsEnding(handle)) g_BMSState.breakBodyStrength = StringToDouble(FileReadString(handle));
   if(!FileIsEnding(handle)) g_BMSState.barsSinceBreak    = (int)StringToInteger(FileReadString(handle));

   FileClose(handle);

   if(g_BMSState.armed)
      CLS_Log(CLS_LOG_INFO, "SetupD", StringFormat(
         "Restored armed BMS state from %s (direction=%s, breakLevel=%.5f, barsSinceBreak=%d).",
         path, CLS_DirectionToString(g_BMSState.direction), g_BMSState.breakLevel, g_BMSState.barsSinceBreak));
}

bool CLS_DetectSetupD_BMSContinuation(const SSetupContext &ctx, SSetupSignal &signal)
{
   if(!InpEnableSetupD)
      return false;

   const string symbol = ctx.symbol;
   const double close1 = iClose(symbol, PERIOD_CURRENT, 1);
   const double open1  = iOpen(symbol, PERIOD_CURRENT, 1);
   const double body1  = CLS_CandleBody(symbol, PERIOD_CURRENT, 1);

   // Phase 2: already armed from an earlier break - look for the pullback
   // candle that triggers entry, or invalidate/expire the armed state.
   if(g_BMSState.armed)
   {
      g_BMSState.barsSinceBreak++;

      if(g_BMSState.direction == CLS_DIR_BUY)
      {
         if(close1 < g_BMSState.breakLevel)
         {
            g_BMSState.armed = false; // broke back through - structure invalidated
         }
         else if(close1 > open1)
         {
            signal.setupType   = CLS_SETUP_D_BMS_CONTINUATION;
            signal.direction   = CLS_DIR_BUY;
            signal.barTime     = ctx.barTime;
            signal.entryPrice  = close1;
            CLS_BuildStopsFromATR(CLS_DIR_BUY, close1, ctx.atrValue, InpStopLossATRMultiplier, InpTakeProfitRMultiple,
                                   signal.stopLoss, signal.takeProfit);
            signal.stopLoss    = MathMin(signal.stopLoss, g_BMSState.breakLevel - ctx.atrValue * 0.1);
            signal.rawStrength = g_BMSState.breakBodyStrength;
            signal.isValid     = true;
            g_BMSState.armed = false; // one shot per break
            CLS_SetupD_SaveState();
            return true;
         }
      }
      else if(g_BMSState.direction == CLS_DIR_SELL)
      {
         if(close1 > g_BMSState.breakLevel)
         {
            g_BMSState.armed = false;
         }
         else if(close1 < open1)
         {
            signal.setupType   = CLS_SETUP_D_BMS_CONTINUATION;
            signal.direction   = CLS_DIR_SELL;
            signal.barTime     = ctx.barTime;
            signal.entryPrice  = close1;
            CLS_BuildStopsFromATR(CLS_DIR_SELL, close1, ctx.atrValue, InpStopLossATRMultiplier, InpTakeProfitRMultiple,
                                   signal.stopLoss, signal.takeProfit);
            signal.stopLoss    = MathMax(signal.stopLoss, g_BMSState.breakLevel + ctx.atrValue * 0.1);
            signal.rawStrength = g_BMSState.breakBodyStrength;
            signal.isValid     = true;
            g_BMSState.armed = false;
            CLS_SetupD_SaveState();
            return true;
         }
      }

      if(g_BMSState.barsSinceBreak > CLS_BMS_MAX_PULLBACK_WAIT_BARS)
         g_BMSState.armed = false; // pullback never came in time

      // Covers this bar's barsSinceBreak increment and any invalidation/expiry
      // above that did not already return - one save per bar while in Phase 2.
      CLS_SetupD_SaveState();

      if(g_BMSState.armed)
         return false; // still waiting, nothing to emit this bar
   }

   // Phase 1: not armed - look for a fresh, strong-bodied break of structure.
   double swingHigh, swingLow;
   int    swingHighShift, swingLowShift;
   const bool hasSwingHigh = CLS_FindSwingHigh(symbol, PERIOD_CURRENT, 2, InpSwingLookbackBars, InpFractalWingBars,
                                                swingHigh, swingHighShift);
   const bool hasSwingLow  = CLS_FindSwingLow(symbol, PERIOD_CURRENT, 2, InpSwingLookbackBars, InpFractalWingBars,
                                               swingLow, swingLowShift);

   const double minBody = ctx.atrValue * InpBMSMinBodyATRPct;
   const double bodyStrength = MathMin(1.0, body1 / MathMax(ctx.atrValue, CLS_PRICE_EPSILON));

   if(hasSwingHigh && close1 > swingHigh && body1 >= minBody && close1 > open1)
   {
      g_BMSState.armed             = true;
      g_BMSState.direction         = CLS_DIR_BUY;
      g_BMSState.breakLevel        = swingHigh;
      g_BMSState.breakBodyStrength = bodyStrength;
      g_BMSState.barsSinceBreak    = 0;
      CLS_SetupD_SaveState();
      return false; // armed now, continuation entry fires on a later pullback bar
   }

   if(hasSwingLow && close1 < swingLow && body1 >= minBody && close1 < open1)
   {
      g_BMSState.armed             = true;
      g_BMSState.direction         = CLS_DIR_SELL;
      g_BMSState.breakLevel        = swingLow;
      g_BMSState.breakBodyStrength = bodyStrength;
      g_BMSState.barsSinceBreak    = 0;
      CLS_SetupD_SaveState();
      return false;
   }

   return false;
}

#endif // CLSAGENT_SETUPD_BMSCONTINUATION_MQH
