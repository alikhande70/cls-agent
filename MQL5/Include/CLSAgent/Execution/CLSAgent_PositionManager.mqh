//+------------------------------------------------------------------+
//|                                      CLSAgent_PositionManager.mqh |
//|   CLS Agent v2.4+ - Execution / Position Manager - Part 7        |
//|                                                                    |
//|   Runs once per closed bar (same cadence as the rest of the         |
//|   pipeline - see CLSAgent.mq5's OnTick()), not per-tick. Scans this  |
//|   chart's own open positions (symbol + magic range, same filter as   |
//|   CLSAgent_BasketRisk.mqh) and applies, in order, Breakeven ->        |
//|   Partial Exit -> Trailing. Each stage's local currentSL is updated   |
//|   immediately after a successful modify so a later stage in the       |
//|   same pass sees the freshly-applied level instead of a stale one.     |
//|                                                                         |
//|   R-multiple basis: oneR = ctx.atrValue * InpStopLossATRMultiplier -   |
//|   a deliberate stateless approximation of each position's original     |
//|   stop distance. The real stop Setup A-D placed is slightly wider       |
//|   (extra room to clear a sweep wick or structure level), and once        |
//|   breakeven/trailing has moved SL the original distance can no longer    |
//|   be re-read from the broker anyway. Re-deriving and caching the exact    |
//|   per-ticket value would add state for a number that only gates when      |
//|   these triggers arm, not the actual risk - the approximation is good      |
//|   enough for that and keeps this stage as stateless as BasketRisk.          |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_POSITIONMANAGER_MQH
#define CLSAGENT_POSITIONMANAGER_MQH

#include "../Core/CLSAgent_Types.mqh"
#include "../Core/CLSAgent_Constants.mqh"
#include "../Core/CLSAgent_Inputs.mqh"
#include "../Core/CLSAgent_Utils.mqh"
#include "../Market/CLSAgent_SymbolProfile.mqh"
#include "CLSAgent_OrderSender.mqh"
#include "CLSAgent_Trailing.mqh"
#include "CLSAgent_PartialExit.mqh"

//+------------------------------------------------------------------+
//| Silent no-op whenever context is invalid or ATR is not ready -      |
//| same convention as the rest of the pipeline (BasketExecutor, etc).  |
//+------------------------------------------------------------------+
void CLS_ManageOpenPositions(const SSetupContext &ctx)
{
   if(!ctx.isContextValid || ctx.atrValue <= 0.0)
      return;

   const double oneR = ctx.atrValue * InpStopLossATRMultiplier;
   if(oneR <= 0.0)
      return;

   MqlTick tick;
   if(!SymbolInfoTick(ctx.symbol, tick))
      return;

   const long magicBase = (long)InpMagicNumber;
   ulong liveTickets[];
   ArrayResize(liveTickets, 0);

   const int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != ctx.symbol)
         continue;

      const long magic = (long)PositionGetInteger(POSITION_MAGIC);
      if(magic < magicBase || magic >= magicBase + CLS_MAX_SETUPS)
         continue; // not one of this EA's orders

      const int n = ArraySize(liveTickets);
      ArrayResize(liveTickets, n + 1);
      liveTickets[n] = ticket;

      const ENUM_POSITION_TYPE posType   = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double             openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      const double             volume    = PositionGetDouble(POSITION_VOLUME);
      double                   currentSL = PositionGetDouble(POSITION_SL);
      const double             currentTP = PositionGetDouble(POSITION_TP);

      const double currentPrice   = (posType == POSITION_TYPE_BUY) ? tick.bid : tick.ask;
      const double profitDistance = (posType == POSITION_TYPE_BUY) ? (currentPrice - openPrice) : (openPrice - currentPrice);
      const double rMultiple      = profitDistance / oneR;

      // Breakeven: self-guards via "is currentSL already on the profit side of breakeven" - no extra state needed.
      if(InpUseBreakeven && rMultiple >= InpBreakevenTriggerR)
      {
         const double offset   = InpBreakevenOffsetPoints * g_SymbolProfile.point;
         const double beSL     = (posType == POSITION_TYPE_BUY) ? (openPrice + offset) : (openPrice - offset);
         const bool   improves = (posType == POSITION_TYPE_BUY) ? (currentSL <= 0.0 || beSL > currentSL)
                                                                  : (currentSL <= 0.0 || beSL < currentSL);
         if(improves && CLS_ModifyPositionStops(ticket, ctx.symbol, beSL, currentTP))
            currentSL = beSL;
      }

      // Partial exit: one-shot per ticket, guarded by CLSAgent_PartialExit.mqh's own cache.
      if(InpUsePartialExit && rMultiple >= InpPartialExitTriggerR)
         CLS_TryPartialExit(ticket, ctx.symbol, posType, volume);

      // Trailing: self-guards via "candidate strictly better by >= InpTrailingStopStepPoints" - no extra state needed.
      if(InpUseTrailingStop && rMultiple >= InpTrailingStopTriggerR)
      {
         double newSL;
         if(CLS_ComputeTrailingStop(posType, currentPrice, currentSL, ctx.atrValue, newSL))
         {
            if(CLS_ModifyPositionStops(ticket, ctx.symbol, newSL, currentTP))
               currentSL = newSL;
         }
      }
   }

   CLS_PartialExit_Prune(liveTickets, ArraySize(liveTickets));
}

//+------------------------------------------------------------------+
//| Hard circuit breaker for Rule #7's daily loss limit: before this,    |
//| CLS_IsDailyLossLimitHit() (Risk/CLSAgent_DailyLimits.mqh) only ever     |
//| blocked new entries, leaving any already-open basket to run               |
//| unmanaged for the rest of the broker day. Closes every open position       |
//| this EA owns on this symbol (any direction/setup), at market,               |
//| immediately. Safe to call every tick - it is just a fresh                     |
//| PositionsTotal() scan (same magic-range filter as CLS_ScanCurrentBasket()      |
//| / CLS_ManageOpenPositions() above) and is a no-op once nothing of this          |
//| EA's remains open. If a close attempt fails (e.g. transient broker               |
//| rejection), the position stays open and the next tick's scan retries it            |
//| - no extra state needed for that.                                                    |
//+------------------------------------------------------------------+
void CLS_FlattenAllPositions(const string symbol, const string reason)
{
   const long magicBase = (long)InpMagicNumber;

   ulong tickets[];
   ArrayResize(tickets, 0);

   const int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;

      const long magic = (long)PositionGetInteger(POSITION_MAGIC);
      if(magic < magicBase || magic >= magicBase + CLS_MAX_SETUPS)
         continue; // not one of this EA's orders

      const int n = ArraySize(tickets);
      ArrayResize(tickets, n + 1);
      tickets[n] = ticket;
   }

   const int n = ArraySize(tickets);
   if(n == 0)
      return;

   CLS_Log(CLS_LOG_ERROR, "PositionManager", StringFormat(
      "%s breached - flattening %d open position(s) on %s.", reason, n, symbol));

   for(int i = 0; i < n; i++)
   {
      if(!PositionSelectByTicket(tickets[i]))
         continue;

      const ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double             volume  = PositionGetDouble(POSITION_VOLUME);

      CLS_ClosePositionFull(tickets[i], symbol, posType, volume);
   }
}

#endif // CLSAGENT_POSITIONMANAGER_MQH
