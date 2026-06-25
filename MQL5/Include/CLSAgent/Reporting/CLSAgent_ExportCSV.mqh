//+------------------------------------------------------------------+
//|                                         CLSAgent_ExportCSV.mqh   |
//|   CLS Agent v2.4+ - Reporting / Performance Export - Part 9      |
//|                                                                    |
//|   A point-in-time snapshot, not an append-only log like Journal/    |
//|   TradeLog/BasketLog (Part 8) - this file is fully overwritten        |
//|   every time it is exported, since it only ever needs to answer        |
//|   "what are the running totals right now," never "what happened          |
//|   on every past bar." Lives in CLS_FILES_REPORTS_DIR, not _LOGS_DIR,       |
//|   to keep that distinction visible on disk too.                              |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_EXPORTCSV_MQH
#define CLSAGENT_EXPORTCSV_MQH

#include "../Core/CLSAgent_Types.mqh"
#include "../Core/CLSAgent_Constants.mqh"
#include "../Core/CLSAgent_Inputs.mqh"
#include "../Core/CLSAgent_Utils.mqh"
#include "../Memory/CLSAgent_PerformanceStats.mqh"

string CLS_ExportCSV_StatsRow(const string label, const SPerformanceStats &s)
{
   return StringFormat("%s,%d,%d,%d,%.1f,%.2f,%.2f,%.2f",
      label, s.tradesClosed, s.wins, s.losses,
      CLS_PerformanceStats_WinRate(s), CLS_PerformanceStats_ProfitFactor(s),
      s.grossProfit, s.grossLoss);
}

//+------------------------------------------------------------------+
//| Overwrites CLSAgent\reports\performance.csv with the current        |
//| running totals - safe to call as often as desired, each call simply   |
//| replaces the previous snapshot. No-op (returns true) when              |
//| InpLogToFile is off, same convention as CLSAgent_CsvWriter.mqh.          |
//+------------------------------------------------------------------+
bool CLS_Report_ExportPerformanceCSV()
{
   if(!InpLogToFile)
      return true;

   const string path   = CLS_FILES_REPORTS_DIR + "performance.csv";
   const int    handle = FileOpen(path, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      CLS_Log(CLS_LOG_ERROR, "Reporting", StringFormat("Failed to open %s, error=%d.", path, GetLastError()));
      return false;
   }

   FileWrite(handle, "setup,trades,wins,losses,winRatePct,profitFactor,grossProfit,grossLoss");
   FileWrite(handle, CLS_ExportCSV_StatsRow("ALL", g_PerfStats[0]));
   FileWrite(handle, CLS_ExportCSV_StatsRow(EnumToString(CLS_SETUP_A_ASIAN_SWEEP),      g_PerfStats[(int)CLS_SETUP_A_ASIAN_SWEEP]));
   FileWrite(handle, CLS_ExportCSV_StatsRow(EnumToString(CLS_SETUP_B_DAILY_HUNT),       g_PerfStats[(int)CLS_SETUP_B_DAILY_HUNT]));
   FileWrite(handle, CLS_ExportCSV_StatsRow(EnumToString(CLS_SETUP_C_FVG_FILL),         g_PerfStats[(int)CLS_SETUP_C_FVG_FILL]));
   FileWrite(handle, CLS_ExportCSV_StatsRow(EnumToString(CLS_SETUP_D_BMS_CONTINUATION), g_PerfStats[(int)CLS_SETUP_D_BMS_CONTINUATION]));
   FileWrite(handle, CLS_ExportCSV_StatsRow(EnumToString(CLS_SETUP_E_ORDER_BLOCK_REJECTION), g_PerfStats[(int)CLS_SETUP_E_ORDER_BLOCK_REJECTION]));

   FileClose(handle);

   CLS_Log(CLS_LOG_INFO, "Reporting", StringFormat("Performance snapshot exported to %s.", path));
   return true;
}

#endif // CLSAGENT_EXPORTCSV_MQH
