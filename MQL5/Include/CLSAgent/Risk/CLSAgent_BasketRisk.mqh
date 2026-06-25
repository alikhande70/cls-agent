//+------------------------------------------------------------------+
//|                                         CLSAgent_BasketRisk.mqh  |
//|   CLS Agent v2.4+ - Risk / Basket Risk - Part 5                  |
//|                                                                    |
//|   A "basket" is every open position on this chart's symbol opened  |
//|   by this EA - magic number within CLS_MAX_SETUPS of InpMagicNumber |
//|   - in the same direction as the prospective signal. Rule #3/#4:    |
//|   risk is tracked per basket, not per order, so                     |
//|   this always reads basket state fresh from live positions instead  |
//|   of a separately maintained tally that could drift from the        |
//|   broker's own book. Basket Execution (Part 6) is expected to reuse  |
//|   this same scan as its source of truth.                            |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_BASKETRISK_MQH
#define CLSAGENT_BASKETRISK_MQH

#include "../Core/CLSAgent_Types.mqh"
#include "../Core/CLSAgent_Constants.mqh"
#include "../Core/CLSAgent_Inputs.mqh"

//+------------------------------------------------------------------+
//| Returns false (basket fields left at defaults) when there is no    |
//| open position of this EA, on this symbol, in this direction yet.   |
//+------------------------------------------------------------------+
bool CLS_ScanCurrentBasket(const string symbol, const ENUM_CLS_DIRECTION direction, SBasketInfo &basket)
{
   basket = SBasketInfo();
   basket.direction = direction;

   if(direction == CLS_DIR_NONE)
      return false;

   const ENUM_POSITION_TYPE wantType  = (direction == CLS_DIR_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   const long               magicBase = (long)InpMagicNumber;

   double   sumLots          = 0.0;
   double   sumEntryWeighted = 0.0;
   double   sumFloatingPnl   = 0.0;
   datetime earliestOpen     = 0;

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

      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != wantType)
         continue;

      const double   lots     = PositionGetDouble(POSITION_VOLUME);
      const double   entry    = PositionGetDouble(POSITION_PRICE_OPEN);
      const double   pnl      = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      const datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

      basket.ordersCount++;
      sumLots          += lots;
      sumEntryWeighted += lots * entry;
      sumFloatingPnl   += pnl;
      if(earliestOpen == 0 || openTime < earliestOpen)
         earliestOpen = openTime;
   }

   if(basket.ordersCount == 0)
      return false;

   basket.totalLots    = sumLots;
   basket.averageEntry = (sumLots > 0.0) ? (sumEntryWeighted / sumLots) : 0.0;
   basket.openTime     = earliestOpen;
   basket.isLosing      = sumFloatingPnl < 0.0;
   // The configured target, not measured from live stop distances -
   // LotCalculator already sized every order to its even split of it.
   basket.totalRiskPercent = InpBasketRiskPercent;

   return true;
}

#endif // CLSAGENT_BASKETRISK_MQH
