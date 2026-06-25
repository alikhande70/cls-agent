//+------------------------------------------------------------------+
//|                                      CLSAgent_BasketExecutor.mqh |
//|   CLS Agent v2.4+ - Execution / Basket Executor - Part 6         |
//|                                                                    |
//|   Last pipeline stage before Position Manager (Part 7). Acts only  |
//|   on a signal the Risk Engine (Part 5) already approved - it never  |
//|   re-derives or re-checks basket/risk policy itself. Its own gate    |
//|   is g_State.tradingAllowedByMode (Mode=AUTO_TRADE AND AutoTrade=    |
//|   true), recomputed every tick by CLSAgent.mq5. Rule #1 (the LLM     |
//|   never sends orders) is enforced structurally here, not by a        |
//|   runtime flag: this function's only inputs are the deterministic    |
//|   pipeline's own structs, and it is the single call site in the      |
//|   whole project that may ever reach CLS_SendMarketOrder().           |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_BASKETEXECUTOR_MQH
#define CLSAGENT_BASKETEXECUTOR_MQH

#include "../Core/CLSAgent_Types.mqh"
#include "../Core/CLSAgent_Constants.mqh"
#include "../Core/CLSAgent_Inputs.mqh"
#include "../Core/CLSAgent_State.mqh"
#include "../Core/CLSAgent_Utils.mqh"
#include "CLSAgent_OrderSender.mqh"

//+------------------------------------------------------------------+
//| Magic layout from CLSAgent_Constants.mqh: every live position's    |
//| magic number alone identifies the setup that opened it.            |
//+------------------------------------------------------------------+
int CLS_MagicOffsetForSetup(const ENUM_CLS_SETUP_TYPE setupType)
{
   switch(setupType)
   {
      case CLS_SETUP_A_ASIAN_SWEEP:           return CLS_MAGIC_OFFSET_SETUP_A;
      case CLS_SETUP_B_DAILY_HUNT:            return CLS_MAGIC_OFFSET_SETUP_B;
      case CLS_SETUP_C_FVG_FILL:              return CLS_MAGIC_OFFSET_SETUP_C;
      case CLS_SETUP_D_BMS_CONTINUATION:       return CLS_MAGIC_OFFSET_SETUP_D;
      case CLS_SETUP_E_ORDER_BLOCK_REJECTION:  return CLS_MAGIC_OFFSET_SETUP_E;
   }
   return 0;
}

// Short codes, not EnumToString() - MT5 order comments are capped at
// ~31 chars by most brokers and EnumToString() names alone can exceed that.
string CLS_SetupShortCode(const ENUM_CLS_SETUP_TYPE setupType)
{
   switch(setupType)
   {
      case CLS_SETUP_A_ASIAN_SWEEP:           return "A";
      case CLS_SETUP_B_DAILY_HUNT:            return "B";
      case CLS_SETUP_C_FVG_FILL:              return "C";
      case CLS_SETUP_D_BMS_CONTINUATION:       return "D";
      case CLS_SETUP_E_ORDER_BLOCK_REJECTION:  return "E";
   }
   return "?";
}

//+------------------------------------------------------------------+
//| Returns true only if an order was actually sent and filled. A      |
//| false return covers three distinct, already-logged-elsewhere cases: |
//| Risk Engine rejected it (logged by the Risk stage), Mode/AutoTrade   |
//| vetoed it (logged below), or the broker rejected/failed the send     |
//| (logged by OrderSender). outTicket is 0 on any false return, and is  |
//| only meaningful to the caller for the Journal (Part 8) - this        |
//| function's own log line already prints it regardless.                |
//+------------------------------------------------------------------+
bool CLS_ExecuteBasketOrder(const SSetupContext &ctx, const SSetupSignal &signal, const SRiskDecision &risk, ulong &outTicket)
{
   outTicket = 0;

   if(!risk.isApproved)
      return false;

   if(!g_State.tradingAllowedByMode)
   {
      CLS_Log(CLS_LOG_INFO, "Execution", StringFormat(
         "%s dir=%s lots=%.2f approved by Risk Engine but Mode=%s/AutoTrade=%s - no order sent.",
         EnumToString(signal.setupType), CLS_DirectionToString(signal.direction), risk.lotSize,
         EnumToString(InpMode), (InpAutoTrade ? "true" : "false")));
      return false;
   }

   const long   magic   = (long)InpMagicNumber + CLS_MagicOffsetForSetup(signal.setupType);
   const string comment = StringFormat("CLS-%s-%s", CLS_SetupShortCode(signal.setupType), CLS_DirectionToString(signal.direction));

   double filledVolume = 0.0, slippagePoints = 0.0;
   const bool sent = CLS_SendMarketOrder(ctx.symbol, signal.direction, risk.lotSize,
                                          signal.stopLoss, signal.takeProfit, magic, comment,
                                          outTicket, filledVolume, slippagePoints);

   CLS_Log(sent ? CLS_LOG_INFO : CLS_LOG_ERROR, "Execution", StringFormat(
      "%s dir=%s lots=%.2f filled=%.2f magic=%d ticket=%I64u sent=%s slippagePts=%.1f",
      EnumToString(signal.setupType), CLS_DirectionToString(signal.direction), risk.lotSize,
      filledVolume, magic, outTicket, (sent ? "true" : "false"), slippagePoints));

   return sent;
}

#endif // CLSAGENT_BASKETEXECUTOR_MQH
