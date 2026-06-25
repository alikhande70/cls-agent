//+------------------------------------------------------------------+
//|                                          CLSAgent_RiskEngine.mqh |
//|   CLS Agent v2.4+ - Risk / Risk Engine - Part 5                  |
//|                                                                    |
//|   Last pipeline gate before Basket Execution (Part 6). Re-checks    |
//|   every Rule #7 hard gate that the Score Engine (Part 4)            |
//|   deliberately left ungated (spread/session/ATR regime), adds       |
//|   DailyLoss and NewsGuard, then enforces Rule #5 (never add to a    |
//|   losing basket) and Rule #3/#4 (basket risk is fixed and split     |
//|   evenly per order slot, never a flat per-order risk, never growing |
//|   with order count) before sizing the order. Runs whenever a setup  |
//|   signal exists regardless of the Decision Engine's verdict, so a   |
//|   complete SRiskDecision always reaches the Journal (Part 8) per    |
//|   Rule #9.                                                          |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_RISKENGINE_MQH
#define CLSAGENT_RISKENGINE_MQH

#include "../Core/CLSAgent_Types.mqh"
#include "../Core/CLSAgent_Constants.mqh"
#include "../Core/CLSAgent_Inputs.mqh"
#include "../Memory/CLSAgent_PerformanceStats.mqh"
#include "CLSAgent_DailyLimits.mqh"
#include "CLSAgent_NewsGuard.mqh"
#include "CLSAgent_BasketRisk.mqh"
#include "CLSAgent_LotCalculator.mqh"

bool CLS_EvaluateRisk(const SSetupContext &ctx, const SSetupSignal &signal, const SScoreResult &score, SRiskDecision &risk)
{
   risk = SRiskDecision();

   if(!ctx.isContextValid || !signal.isValid || score.status != CLS_SIGNAL_ACCEPTED)
   {
      risk.rejectReason = (signal.isValid && score.status == CLS_SIGNAL_REJECTED) ? score.rejectReason : CLS_REJECT_OTHER;
      return false;
   }

   if(!ctx.spreadAllowed)
   {
      risk.rejectReason = CLS_REJECT_SPREAD;
      return false;
   }
   if(!ctx.sessionAllowed)
   {
      risk.rejectReason = CLS_REJECT_SESSION;
      return false;
   }
   if(!ctx.atrRegimeAllowed)
   {
      risk.rejectReason = CLS_REJECT_ATR_REGIME;
      return false;
   }
   if(CLS_IsDailyLossLimitHit())
   {
      risk.rejectReason = CLS_REJECT_DAILY_LOSS;
      return false;
   }
   if(CLS_IsInNewsWindow(TimeCurrent()))
   {
      risk.rejectReason = CLS_REJECT_NEWS;
      return false;
   }

   // Loss-streak protection: pause trading outright once the streak reaches
   // InpLossStreakPauseAt; a win resets g_PerfStats[0].currentLossStreak to 0
   // (CLS_PerformanceStats_Update), which is the only way out of this gate.
   const int lossStreak = g_PerfStats[0].currentLossStreak;
   if(lossStreak >= InpLossStreakPauseAt)
   {
      risk.rejectReason = CLS_REJECT_LOSS_STREAK;
      return false;
   }

   SBasketInfo basket;
   if(CLS_ScanCurrentBasket(ctx.symbol, signal.direction, basket))
   {
      if(CLS_NO_ADD_TO_LOSING_BASKET && basket.isLosing)
      {
         risk.rejectReason = CLS_REJECT_LOSING_BASKET;
         return false;
      }
      if(basket.ordersCount >= InpMaxOrdersPerBasket && !InpSuperBurst)
      {
         risk.rejectReason = CLS_REJECT_BASKET_FULL;
         return false;
      }
   }

   // Rule #3/#4: the whole basket's target risk is fixed at InpBasketRiskPercent
   // and split evenly across its max order slots, so total basket risk never
   // grows as more orders are added - only how many slots are already filled.
   double riskPercentForOrder = InpBasketRiskPercent / (double)InpMaxOrdersPerBasket;

   // Loss-streak protection: once the streak reaches InpLossStreakReduceAt
   // (but hasn't yet hit the pause threshold above), shrink size rather than
   // refuse the trade outright.
   if(lossStreak >= InpLossStreakReduceAt)
      riskPercentForOrder *= InpLossStreakReduceFactor;

   const double lotSize = CLS_CalculateLotSize(signal.entryPrice, signal.stopLoss, riskPercentForOrder);
   if(lotSize <= 0.0)
   {
      risk.rejectReason = CLS_REJECT_OTHER;
      return false;
   }

   risk.isApproved        = true;
   risk.lotSize            = lotSize;
   risk.basketRiskPercent  = riskPercentForOrder;
   risk.rejectReason       = CLS_REJECT_NONE;
   return true;
}

#endif // CLSAGENT_RISKENGINE_MQH
