//+------------------------------------------------------------------+
//|                                          CLSAgent_TradeLog.mqh   |
//|   CLS Agent v2.4+ - Memory / Trade Log - Part 8                  |
//|                                                                    |
//|   Driven from OnTradeTransaction() in CLSAgent.mq5, not from the     |
//|   OnTick() bar cadence - a position can close via the broker filling  |
//|   its SL/TP directly, which this EA's own code never explicitly        |
//|   requests, so the only reliable detection point is the deal history    |
//|   itself. Logs only the closing side (DEAL_ENTRY_OUT/OUT_BY); the open   |
//|   side is already covered by OrderSender's/BasketExecutor's own logs.     |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_TRADELOG_MQH
#define CLSAGENT_TRADELOG_MQH

#include "../Core/CLSAgent_Types.mqh"
#include "../Core/CLSAgent_Constants.mqh"
#include "../Core/CLSAgent_Inputs.mqh"
#include "../Core/CLSAgent_Utils.mqh"
#include "CLSAgent_CsvWriter.mqh"
#include "CLSAgent_PerformanceStats.mqh"

//+------------------------------------------------------------------+
//| Mirrors CLSAgent_BasketExecutor.mqh's magic-offset layout in the     |
//| other direction: magic -> setup, instead of setup -> magic.          |
//+------------------------------------------------------------------+
ENUM_CLS_SETUP_TYPE CLS_TradeLog_SetupFromMagic(const long magic)
{
   const long offset = magic - (long)InpMagicNumber;
   if(offset == CLS_MAGIC_OFFSET_SETUP_A) return CLS_SETUP_A_ASIAN_SWEEP;
   if(offset == CLS_MAGIC_OFFSET_SETUP_B) return CLS_SETUP_B_DAILY_HUNT;
   if(offset == CLS_MAGIC_OFFSET_SETUP_C) return CLS_SETUP_C_FVG_FILL;
   if(offset == CLS_MAGIC_OFFSET_SETUP_D) return CLS_SETUP_D_BMS_CONTINUATION;
   if(offset == CLS_MAGIC_OFFSET_SETUP_E) return CLS_SETUP_E_ORDER_BLOCK_REJECTION;
   return CLS_SETUP_NONE;
}

//+------------------------------------------------------------------+
//| Call once per TRADE_TRANSACTION_DEAL_ADD from OnTradeTransaction().  |
//| Silent no-op for any deal that is not one of this EA's own closes.   |
//+------------------------------------------------------------------+
void CLS_TradeLog_OnDealAdded(const ulong dealTicket)
{
   if(!HistoryDealSelect(dealTicket))
      return;

   if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol)
      return;

   const long magic     = (long)HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
   const long magicBase = (long)InpMagicNumber;
   if(magic < magicBase || magic >= magicBase + CLS_MAX_SETUPS)
      return; // not one of this EA's orders

   const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
      return; // only the closing side of a position is logged here

   const double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                          + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   const double   volume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
   const double   price  = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
   const datetime time   = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
   const ulong    posId  = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);

   const ENUM_CLS_SETUP_TYPE setupType = CLS_TradeLog_SetupFromMagic(magic);

   static const string header = "time,symbol,setup,magic,positionId,closeVolume,closePrice,profit";
   const string line = StringFormat("%s,%s,%s,%d,%I64u,%.2f,%.5f,%.2f",
      TimeToString(time, TIME_DATE | TIME_SECONDS), _Symbol, EnumToString(setupType), magic, posId, volume, price, profit);
   CLS_Csv_AppendLine("trades.csv", header, line);

   CLS_PerformanceStats_Update(setupType, profit);
}

#endif // CLSAGENT_TRADELOG_MQH
