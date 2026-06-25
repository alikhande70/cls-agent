//+------------------------------------------------------------------+
//|                                        CLSAgent_OrderSender.mqh  |
//|   CLS Agent v2.4+ - Execution / Order Sender - Part 6            |
//|                                                                    |
//|   Pure broker-mechanics layer: builds one MqlTradeRequest, sends   |
//|   it, and retries up to InpOrderRetryCount times (InpOrderRetryDelayMs |
//|   apart) but only on transient rejections (requote/timeout/price   |
//|   moved) - never on rejections a retry cannot fix (invalid stops,   |
//|   no money, trading disabled). Knows nothing about setups, scoring  |
//|   or baskets - BasketExecutor (Part 6) owns that policy and calls    |
//|   CLS_SendMarketOrder(). Part 7 (Position Management) reuses this    |
//|   same mechanics layer for its own two actions - modifying an open    |
//|   position's SL/TP and partially closing it - via                     |
//|   CLS_ModifyPositionStops()/CLS_ClosePositionPartial() below; neither  |
//|   retries, since Position Management re-evaluates and retries on its   |
//|   own next pass instead of blocking here.                              |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_ORDERSENDER_MQH
#define CLSAGENT_ORDERSENDER_MQH

#include "../Core/CLSAgent_Types.mqh"
#include "../Core/CLSAgent_Inputs.mqh"
#include "../Core/CLSAgent_Utils.mqh"
#include "../Market/CLSAgent_SymbolProfile.mqh"

//+------------------------------------------------------------------+
//| FOK if the broker supports it, else IOC, else RETURN - sending an  |
//| unsupported filling mode is an instant broker-side rejection.      |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING CLS_ResolveFillingMode(const string symbol)
{
   const int mode = (int)SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
   if((mode & SYMBOL_FILLING_FOK) != 0)
      return ORDER_FILLING_FOK;
   if((mode & SYMBOL_FILLING_IOC) != 0)
      return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

//+------------------------------------------------------------------+
//| Re-checked fresh on every retry attempt, since price moves between  |
//| attempts - reads the live stops/freeze level off the SymbolProfile  |
//| snapshot rather than trusting the price the signal was detected at. |
//+------------------------------------------------------------------+
bool CLS_ValidateStopDistance(const string symbol, const ENUM_CLS_DIRECTION direction,
                               const double stopLoss, const double takeProfit, double &outPrice)
{
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
      return false;

   outPrice = (direction == CLS_DIR_BUY) ? tick.ask : tick.bid;

   const int    minPoints   = (g_SymbolProfile.stopsLevelPoints > g_SymbolProfile.freezeLevelPoints)
                                  ? g_SymbolProfile.stopsLevelPoints : g_SymbolProfile.freezeLevelPoints;
   const double minDistance = minPoints * g_SymbolProfile.point;
   if(minDistance <= 0.0)
      return true; // broker reports no minimum distance to enforce

   if(MathAbs(outPrice - stopLoss) < minDistance)
      return false;
   if(takeProfit > 0.0 && MathAbs(outPrice - takeProfit) < minDistance)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Rejections worth retrying: transient, price/connection related.    |
//| Everything else (invalid stops, no money, volume, disabled trading) |
//| will fail again identically, so retrying would only waste time.    |
//+------------------------------------------------------------------+
bool CLS_IsRetryableRetcode(const uint retcode)
{
   switch(retcode)
   {
      case TRADE_RETCODE_REQUOTE:
      case TRADE_RETCODE_PRICE_CHANGED:
      case TRADE_RETCODE_PRICE_OFF:
      case TRADE_RETCODE_TIMEOUT:
      case TRADE_RETCODE_CONNECTION:
      case TRADE_RETCODE_TOO_MANY_REQUESTS:
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Sends one market order. Returns false and leaves outOrderTicket=0  |
//| if every attempt failed or the stop distance was rejected before    |
//| ever reaching the broker.                                           |
//+------------------------------------------------------------------+
bool CLS_SendMarketOrder(const string symbol, const ENUM_CLS_DIRECTION direction, const double volume,
                          const double stopLoss, const double takeProfit, const long magic, const string comment,
                          ulong &outOrderTicket)
{
   outOrderTicket = 0;

   for(int attempt = 1; attempt <= InpOrderRetryCount; attempt++)
   {
      double entryPrice;
      if(!CLS_ValidateStopDistance(symbol, direction, stopLoss, takeProfit, entryPrice))
      {
         CLS_Log(CLS_LOG_WARNING, "OrderSender", "Stop/target too close to current price for broker's stops/freeze level - skipping send.");
         return false;
      }

      MqlTradeRequest request;
      MqlTradeResult  result;
      ZeroMemory(request);
      ZeroMemory(result);

      request.action       = TRADE_ACTION_DEAL;
      request.symbol       = symbol;
      request.volume       = volume;
      request.type         = (direction == CLS_DIR_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      request.price        = entryPrice;
      request.sl           = stopLoss;
      request.tp           = takeProfit;
      request.deviation    = InpMaxSlippagePoints;
      request.magic        = magic;
      request.comment      = comment;
      request.type_filling = CLS_ResolveFillingMode(symbol);

      if(!OrderSend(request, result))
      {
         CLS_Log(CLS_LOG_ERROR, "OrderSender", StringFormat(
            "OrderSend() call failed, GetLastError=%d (attempt %d/%d).", GetLastError(), attempt, InpOrderRetryCount));
      }
      else if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_DONE_PARTIAL)
      {
         outOrderTicket = result.order;
         CLS_Log(CLS_LOG_INFO, "OrderSender", StringFormat(
            "Order filled, ticket=%I64u retcode=%d (attempt %d/%d).", result.order, result.retcode, attempt, InpOrderRetryCount));
         return true;
      }
      else if(!CLS_IsRetryableRetcode(result.retcode))
      {
         CLS_Log(CLS_LOG_ERROR, "OrderSender", StringFormat(
            "Order rejected, non-retryable retcode=%d \"%s\".", result.retcode, result.comment));
         return false;
      }
      else
      {
         CLS_Log(CLS_LOG_WARNING, "OrderSender", StringFormat(
            "Order rejected, retryable retcode=%d \"%s\" - attempt %d/%d.", result.retcode, result.comment, attempt, InpOrderRetryCount));
      }

      if(attempt < InpOrderRetryCount)
         Sleep(InpOrderRetryDelayMs);
   }

   CLS_Log(CLS_LOG_ERROR, "OrderSender", "Order send failed after all retry attempts.");
   return false;
}

//+------------------------------------------------------------------+
//| Modifies an open position's SL/TP. No retry loop - Position        |
//| Management (Part 7) re-evaluates and retries on its own next pass   |
//| rather than blocking the tick here.                                  |
//+------------------------------------------------------------------+
bool CLS_ModifyPositionStops(const ulong ticket, const string symbol, const double newSL, const double newTP)
{
   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action   = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.symbol   = symbol;
   request.sl       = newSL;
   request.tp       = newTP;

   if(!OrderSend(request, result) || (result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_DONE_PARTIAL))
   {
      CLS_Log(CLS_LOG_WARNING, "OrderSender", StringFormat(
         "SL/TP modify failed for ticket=%I64u retcode=%d \"%s\".", ticket, result.retcode, result.comment));
      return false;
   }

   CLS_Log(CLS_LOG_INFO, "OrderSender", StringFormat(
      "SL/TP modified for ticket=%I64u newSL=%.5f newTP=%.5f.", ticket, newSL, newTP));
   return true;
}

//+------------------------------------------------------------------+
//| Closes part of an open position at market. No retry loop - same     |
//| reasoning as CLS_ModifyPositionStops() above.                       |
//+------------------------------------------------------------------+
bool CLS_ClosePositionPartial(const ulong ticket, const string symbol, const ENUM_POSITION_TYPE posType, const double volume)
{
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
      return false;

   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action       = TRADE_ACTION_DEAL;
   request.position     = ticket;
   request.symbol       = symbol;
   request.volume       = volume;
   request.type         = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price        = (posType == POSITION_TYPE_BUY) ? tick.bid : tick.ask;
   request.deviation    = InpMaxSlippagePoints;
   request.type_filling = CLS_ResolveFillingMode(symbol);

   if(!OrderSend(request, result) || (result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_DONE_PARTIAL))
   {
      CLS_Log(CLS_LOG_WARNING, "OrderSender", StringFormat(
         "Partial close failed for ticket=%I64u retcode=%d \"%s\".", ticket, result.retcode, result.comment));
      return false;
   }

   CLS_Log(CLS_LOG_INFO, "OrderSender", StringFormat(
      "Partial close sent for ticket=%I64u volume=%.2f.", ticket, volume));
   return true;
}

#endif // CLSAGENT_ORDERSENDER_MQH
