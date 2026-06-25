//+------------------------------------------------------------------+
//|                                         CLSAgent_CsvWriter.mqh   |
//|   CLS Agent v2.4+ - Memory / CSV Writer - Part 8                 |
//|                                                                    |
//|   Single shared append-only-file helper reused by every Memory      |
//|   module (Journal, TradeLog, BasketLog) so the "open, seek to end,   |
//|   write header once, append" dance lives in exactly one place.       |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_CSVWRITER_MQH
#define CLSAGENT_CSVWRITER_MQH

#include "../Core/CLSAgent_Constants.mqh"
#include "../Core/CLSAgent_Inputs.mqh"
#include "../Core/CLSAgent_Utils.mqh"

//+------------------------------------------------------------------+
//| No-op (returns true) when InpLogToFile is off - console logging via |
//| CLS_Log() still happens regardless, this only gates the CSV mirror.  |
//| FILE_READ is required alongside FILE_WRITE so FileSeek(SEEK_END)      |
//| lands after existing content instead of truncating it - MQL5's        |
//| FILE_WRITE alone always (re)creates the file at position 0.            |
//+------------------------------------------------------------------+
bool CLS_Csv_AppendLine(const string fileName, const string headerLine, const string dataLine)
{
   if(!InpLogToFile)
      return true;

   const string path  = CLS_FILES_LOGS_DIR + fileName;
   const bool   isNew = !FileIsExist(path);

   const int handle = FileOpen(path, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      CLS_Log(CLS_LOG_ERROR, "Memory", StringFormat("Failed to open %s, error=%d.", path, GetLastError()));
      return false;
   }

   FileSeek(handle, 0, SEEK_END);
   if(isNew)
      FileWrite(handle, headerLine);
   FileWrite(handle, dataLine);

   FileClose(handle);
   return true;
}

#endif // CLSAGENT_CSVWRITER_MQH
