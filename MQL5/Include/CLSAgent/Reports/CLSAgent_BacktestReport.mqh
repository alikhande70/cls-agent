//+------------------------------------------------------------------+
//|                                      CLSAgent_BacktestReport.mqh |
//|   CLS Agent v2.4+ - Reports / Backtest Report - Part 9           |
//|                                                                    |
//|   OnTester() only fires inside the Strategy Tester, once a full      |
//|   backtest/optimization pass finishes - the one moment a run's        |
//|   totals are final. Reuses the same g_PerfStats the live               |
//|   PerformanceStats module already maintains (Part 8) rather than         |
//|   re-deriving anything from deal history, so backtest and live           |
//|   reporting always agree on what "a win" or "profit factor" means.         |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_BACKTESTREPORT_MQH
#define CLSAGENT_BACKTESTREPORT_MQH

#include "../Core/CLSAgent_Types.mqh"
#include "../Core/CLSAgent_Constants.mqh"
#include "../Core/CLSAgent_Inputs.mqh"
#include "../Core/CLSAgent_Utils.mqh"
#include "../Memory/CLSAgent_PerformanceStats.mqh"

//+------------------------------------------------------------------+
//| Writes a human-readable summary and returns the overall profit       |
//| factor - usable unchanged as OnTester()'s return value, which the     |
//| Strategy Tester's optimizer treats as the criterion to maximize        |
//| when "Custom max" is selected as the optimization criterion.            |
//+------------------------------------------------------------------+
double CLS_BacktestReport_Generate()
{
   const SPerformanceStats total        = g_PerfStats[0];
   const double             profitFactor = CLS_PerformanceStats_ProfitFactor(total);

   if(InpLogToFile)
   {
      const string path   = CLS_FILES_REPORTS_DIR + "backtest_summary.txt";
      const int    handle = FileOpen(path, FILE_WRITE | FILE_TXT | FILE_ANSI);
      if(handle != INVALID_HANDLE)
      {
         FileWrite(handle, StringFormat("%s v%s - Backtest Summary", CLS_AGENT_NAME, CLS_AGENT_VERSION));
         FileWrite(handle, StringFormat("Generated: %s", TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS)));
         FileWrite(handle, "");
         FileWrite(handle, StringFormat("Total trades closed : %d", total.tradesClosed));
         FileWrite(handle, StringFormat("Wins / Losses        : %d / %d", total.wins, total.losses));
         FileWrite(handle, StringFormat("Win rate             : %.1f%%", CLS_PerformanceStats_WinRate(total)));
         FileWrite(handle, StringFormat("Profit factor        : %.2f", profitFactor));
         FileWrite(handle, StringFormat("Gross profit / loss  : %.2f / %.2f", total.grossProfit, total.grossLoss));
         FileWrite(handle, StringFormat("Net P/L              : %.2f", total.grossProfit - total.grossLoss));
         FileWrite(handle, "");
         FileWrite(handle, "Per-setup breakdown:");
         FileWrite(handle, StringFormat("  Setup A (Asian Sweep)      : trades=%d winRate=%.1f%% PF=%.2f",
            g_PerfStats[(int)CLS_SETUP_A_ASIAN_SWEEP].tradesClosed,
            CLS_PerformanceStats_WinRate(g_PerfStats[(int)CLS_SETUP_A_ASIAN_SWEEP]),
            CLS_PerformanceStats_ProfitFactor(g_PerfStats[(int)CLS_SETUP_A_ASIAN_SWEEP])));
         FileWrite(handle, StringFormat("  Setup B (Daily Hunt)       : trades=%d winRate=%.1f%% PF=%.2f",
            g_PerfStats[(int)CLS_SETUP_B_DAILY_HUNT].tradesClosed,
            CLS_PerformanceStats_WinRate(g_PerfStats[(int)CLS_SETUP_B_DAILY_HUNT]),
            CLS_PerformanceStats_ProfitFactor(g_PerfStats[(int)CLS_SETUP_B_DAILY_HUNT])));
         FileWrite(handle, StringFormat("  Setup C (FVG Fill)         : trades=%d winRate=%.1f%% PF=%.2f",
            g_PerfStats[(int)CLS_SETUP_C_FVG_FILL].tradesClosed,
            CLS_PerformanceStats_WinRate(g_PerfStats[(int)CLS_SETUP_C_FVG_FILL]),
            CLS_PerformanceStats_ProfitFactor(g_PerfStats[(int)CLS_SETUP_C_FVG_FILL])));
         FileWrite(handle, StringFormat("  Setup D (BMS Continuation) : trades=%d winRate=%.1f%% PF=%.2f",
            g_PerfStats[(int)CLS_SETUP_D_BMS_CONTINUATION].tradesClosed,
            CLS_PerformanceStats_WinRate(g_PerfStats[(int)CLS_SETUP_D_BMS_CONTINUATION]),
            CLS_PerformanceStats_ProfitFactor(g_PerfStats[(int)CLS_SETUP_D_BMS_CONTINUATION])));

         FileClose(handle);
         CLS_Log(CLS_LOG_INFO, "Reports", StringFormat("Backtest summary written to %s.", path));
      }
      else
      {
         CLS_Log(CLS_LOG_ERROR, "Reports", StringFormat("Failed to open %s, error=%d.", path, GetLastError()));
      }
   }

   return profitFactor;
}

#endif // CLSAGENT_BACKTESTREPORT_MQH
