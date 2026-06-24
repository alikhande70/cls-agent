//+------------------------------------------------------------------+
//|                                                  CLSAgent.mq5    |
//|         CLS Agent v2.4+ - Decision-Safe Contextual Liquidity     |
//|                          Scalping Agent                          |
//|                                                                    |
//|   Pipeline: Market Data -> Context Engine -> Setup Detector ->    |
//|   Score Engine -> Decision Engine -> Risk Engine -> Basket        |
//|   Execution -> Position Manager -> Journal/Memory -> Report.      |
//|                                                                    |
//|   Part 1 built the shell + Core. Part 2 wired the Context Engine   |
//|   stage to the Market modules. Part 3 wired the Setup Detector     |
//|   stage to Strategy/SetupDetector + Setup A/B/C/D. Part 4 wired    |
//|   the Score/Decision Engine stage. Part 5 wires the Risk Engine    |
//|   stage. Stages from Basket Execution onward remain named stubs    |
//|   until Parts 6-9.                                                  |
//+------------------------------------------------------------------+
#property copyright "CLS Agent"
#property link      ""
#property version   "2.40"
#property strict
#property description "Decision-Safe Contextual Liquidity Scalping Agent (CLS Agent v2.4+)"
#property description "Rule-based EA: the LLM never sends orders, it only analyzes/reviews/reports."

#include <CLSAgent/Core/CLSAgent_Constants.mqh>
#include <CLSAgent/Core/CLSAgent_Types.mqh>
#include <CLSAgent/Core/CLSAgent_Inputs.mqh>
#include <CLSAgent/Core/CLSAgent_State.mqh>
#include <CLSAgent/Core/CLSAgent_Utils.mqh>
#include <CLSAgent/Market/CLSAgent_SymbolProfile.mqh>
#include <CLSAgent/Market/CLSAgent_TimeSession.mqh>
#include <CLSAgent/Market/CLSAgent_Indicators.mqh>
#include <CLSAgent/Market/CLSAgent_SpreadBuffer.mqh>
#include <CLSAgent/Market/CLSAgent_ATRRegime.mqh>
#include <CLSAgent/Market/CLSAgent_LevelCache.mqh>
#include <CLSAgent/Strategy/CLSAgent_SetupDetector.mqh>
#include <CLSAgent/Strategy/CLSAgent_ScoreEngine.mqh>
#include <CLSAgent/Strategy/CLSAgent_DecisionEngine.mqh>
#include <CLSAgent/Risk/CLSAgent_RiskEngine.mqh>

//+------------------------------------------------------------------+
//| Pipeline stage stubs still pending (Parts 6-9). Stage 1 (Context  |
//| Engine) is BuildSetupContext() below; Stage 2 (Setup Detector) is  |
//| CLS_DetectSetups(); Stage 3 (Score/Decision Engine) is             |
//| CLS_DecideSignal(); Stage 4 (Risk Engine) is CLS_EvaluateRisk() -   |
//| all called directly from OnTick().                                  |
//+------------------------------------------------------------------+
void Stage_BasketExecution_STUB(const SBasketInfo &basket) { /* Part 6: Execution/OrderSender, BasketExecutor */ }
void Stage_PositionManager_STUB()                          { /* Part 7: Execution/PositionManager, PartialExit, Trailing */ }
void Stage_JournalMemory_STUB()                            { /* Part 8: Memory/Journal, TradeLog, BasketLog, PerformanceStats */ }
void Stage_ReportLLMReview_STUB()                           { /* Part 9: Reports/DebugPanel, BacktestReport, ExportCSV */ }

//+------------------------------------------------------------------+
//| Reject configurations that would be unsafe to run, before the EA  |
//| reaches its first tick.                                            |
//+------------------------------------------------------------------+
bool ValidateInputs()
{
   if(InpBasketRiskPercent <= 0.0 || InpBasketRiskPercent > 5.0)
   {
      CLS_Log(CLS_LOG_ERROR, "Init", "InpBasketRiskPercent out of sane range (0, 5]%.");
      return false;
   }
   if(InpMaxOrdersPerBasket <= 0 || InpMaxOrdersPerBasket > CLS_MAX_ORDERS_PER_BASKET_HARDCAP)
   {
      CLS_Log(CLS_LOG_ERROR, "Init", "InpMaxOrdersPerBasket out of range (1.." + (string)CLS_MAX_ORDERS_PER_BASKET_HARDCAP + ").");
      return false;
   }
   if(InpMaxDailyLossPercent <= 0.0 || InpMaxDailyLossPercent > 20.0)
   {
      CLS_Log(CLS_LOG_ERROR, "Init", "InpMaxDailyLossPercent out of sane range (0, 20]%.");
      return false;
   }
   if(InpAutoTrade && InpMode == CLS_MODE_SIGNAL_ONLY)
      CLS_Log(CLS_LOG_WARNING, "Init", "InpAutoTrade=true but Mode=SIGNAL_ONLY: no orders will be sent regardless.");

   return true;
}

//+------------------------------------------------------------------+
//| Basket logic needs several simultaneous positions on the same     |
//| symbol/direction, which only a hedging-type account preserves as   |
//| distinct positions. Netting accounts merge them - warn, don't      |
//| block, since SIGNAL_ONLY analysis is still useful either way.      |
//+------------------------------------------------------------------+
void CheckAccountMarginMode()
{
   const ENUM_ACCOUNT_MARGIN_MODE marginMode = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(marginMode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      CLS_Log(CLS_LOG_WARNING, "Init",
         "Account is not in hedging mode - Basket Execution (Part 6) needs multiple simultaneous "
         "positions per symbol/direction; a netting account will merge them into one position.");
}

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   g_LogMinLevel = (int)InpLogLevel;

   if(!ValidateInputs())
      return INIT_PARAMETERS_INCORRECT;

   const ENUM_CLS_ASSET_CLASS detectedClass = CLS_ResolveAssetClass(_Symbol);
   CLS_State_Init(_Symbol, detectedClass);

   if(!CLS_BuildSymbolProfile(_Symbol, g_SymbolProfile))
      return INIT_FAILED;

   if(!CLS_Indicators_Init(_Symbol))
      return INIT_FAILED;

   CLS_SpreadBuffer_Init();
   CheckAccountMarginMode();

   CLS_Log(CLS_LOG_INFO, "Init", StringFormat(
      "%s v%s starting on %s | AssetClass=%s | Mode=%s | AutoTrade=%s",
      CLS_AGENT_FULL_NAME, CLS_AGENT_VERSION, _Symbol,
      (detectedClass == CLS_ASSET_GOLD ? "GOLD" : "FOREX"),
      EnumToString(InpMode),
      (InpAutoTrade ? "true" : "false")));

   CLS_Log(CLS_LOG_INFO, "Init", StringFormat(
      "Risk config: BasketRisk=%.2f%% MaxOrdersPerBasket=%d MaxDailyLoss=%.2f%% NoAddToLosingBasket=true (fixed)",
      InpBasketRiskPercent, InpMaxOrdersPerBasket, InpMaxDailyLossPercent));

   CLS_Log(CLS_LOG_INFO, "Init", StringFormat(
      "Symbol profile: digits=%d point=%.*f tickValue=%.5f stopsLevel=%dpt maxSpread=%dpt minScore=%.1f",
      g_SymbolProfile.digits, g_SymbolProfile.digits, g_SymbolProfile.point, g_SymbolProfile.tickValue,
      g_SymbolProfile.stopsLevelPoints, g_SymbolProfile.maxSpreadPoints, g_SymbolProfile.minScoreToTrade));

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   CLS_Indicators_Deinit();
   CLS_Log(CLS_LOG_INFO, "Deinit", StringFormat("CLS Agent stopping. Reason code=%d", reason));
}

//+------------------------------------------------------------------+
//| Recompute whether the current Mode/AutoTrade combo permits orders. |
//| Even when this is true, Basket Execution (Part 6) still gets the   |
//| final veto - this flag only gates whether the EA is allowed to     |
//| attempt sending anything at all.                                    |
//+------------------------------------------------------------------+
void RefreshTradingPermissionFlag()
{
   g_State.tradingAllowedByMode = (InpMode == CLS_MODE_AUTO_TRADE) && InpAutoTrade;
}

//+------------------------------------------------------------------+
//| Context Engine (Part 2) - builds the market snapshot for the      |
//| just-closed bar. Every field the Risk Engine (Part 5) needs for    |
//| Rule #7 (spread/session/ATR regime checked before entry) is        |
//| resolved here, once per bar, instead of being scattered later.     |
//+------------------------------------------------------------------+
SSetupContext BuildSetupContext()
{
   SSetupContext ctx;
   ctx.symbol  = _Symbol;
   ctx.barTime = iTime(_Symbol, PERIOD_CURRENT, 1); // shift=1: the bar that just closed, never shift=0 (forming)

   // Refreshed every bar: brokers can change tick value/stops level intraday.
   if(!CLS_BuildSymbolProfile(_Symbol, g_SymbolProfile))
      return ctx; // isContextValid stays false

   ctx.assetClass = g_SymbolProfile.assetClass;

   ctx.session        = CLS_GetCurrentSession();
   ctx.sessionAllowed = CLS_IsSessionTradeable(ctx.session);

   ctx.spreadPoints  = CLS_SpreadBuffer_Average();
   ctx.spreadAllowed = CLS_SpreadBuffer_IsAcceptable(g_SymbolProfile.maxSpreadPoints);

   ENUM_CLS_ATR_REGIME regime;
   double              atrValue;
   if(!CLS_GetATRRegimeNow(regime, atrValue))
   {
      CLS_Log(CLS_LOG_WARNING, "Context", "ATR history not ready yet - blocking entries this bar.");
      return ctx; // isContextValid stays false until ATR history is ready
   }
   ctx.atrRegime        = regime;
   ctx.atrValue         = atrValue;
   ctx.atrRegimeAllowed = CLS_IsATRRegimeTradeable(regime);

   if(CLS_LevelCache_NeedsUpdate())
      CLS_LevelCache_Update(_Symbol);

   ctx.isContextValid = true;
   return ctx;
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   g_State.ticksProcessed++;

   // Sampled on every tick (not gated by bar-close) so the spread average is
   // already representative of current conditions by the time a bar closes.
   CLS_SpreadBuffer_AddSample(_Symbol);

   if(CLS_State_RolloverDayIfNeeded())
      CLS_Log(CLS_LOG_INFO, "Tick", "New trading day detected, daily P/L baseline reset.");

   RefreshTradingPermissionFlag();

   // Rule #6: act only once per fully closed bar, never on the forming bar.
   if(!CLS_State_IsNewBar(_Symbol, PERIOD_CURRENT))
      return;

   const SSetupContext ctx = BuildSetupContext();

   CLS_Log(CLS_LOG_DEBUG, "Context", StringFormat(
      "Bar=%s Session=%s(%s) ATRRegime=%s(%.5f,%s) Spread=%.1f(%s) Valid=%s",
      TimeToString(ctx.barTime, TIME_DATE | TIME_MINUTES),
      EnumToString(ctx.session), (ctx.sessionAllowed ? "OK" : "BLOCKED"),
      EnumToString(ctx.atrRegime), ctx.atrValue, (ctx.atrRegimeAllowed ? "OK" : "BLOCKED"),
      ctx.spreadPoints, (ctx.spreadAllowed ? "OK" : "BLOCKED"),
      (ctx.isContextValid ? "true" : "false")));

   // Pipeline shape from here on - Parts 6-9 replace the remaining stub calls
   // with real module calls, in order, without changing this call sequence.
   SSetupSignal  signal;
   SScoreResult  score;
   SRiskDecision risk;
   SBasketInfo   basket;

   if(CLS_DetectSetups(ctx, signal))
   {
      const bool accepted = CLS_DecideSignal(ctx, signal, score);
      CLS_Log(accepted ? CLS_LOG_INFO : CLS_LOG_WARNING, "Score", StringFormat(
         "%s dir=%s entry=%.5f SL=%.5f TP=%.5f score=%.1f(min=%.1f) status=%s%s",
         EnumToString(signal.setupType), CLS_DirectionToString(signal.direction),
         signal.entryPrice, signal.stopLoss, signal.takeProfit,
         score.score, g_SymbolProfile.minScoreToTrade, EnumToString(score.status),
         (accepted ? "" : (" reason=" + CLS_RejectReasonToString(score.rejectReason)))));

      const bool approved = CLS_EvaluateRisk(ctx, signal, score, risk);
      CLS_Log(approved ? CLS_LOG_INFO : CLS_LOG_WARNING, "Risk", StringFormat(
         "%s dir=%s lots=%.2f basketRisk=%.2f%% approved=%s%s",
         EnumToString(signal.setupType), CLS_DirectionToString(signal.direction),
         risk.lotSize, risk.basketRiskPercent, (approved ? "true" : "false"),
         (approved ? "" : (" reason=" + CLS_RejectReasonToString(risk.rejectReason)))));
   }

   Stage_BasketExecution_STUB(basket);
   Stage_PositionManager_STUB();
   Stage_JournalMemory_STUB();
   Stage_ReportLLMReview_STUB();
}

//+------------------------------------------------------------------+
//| Timer function - activated in Part 9 to refresh the debug panel.  |
//+------------------------------------------------------------------+
void OnTimer()
{
}

//+------------------------------------------------------------------+
//| Tester evaluation hook - used by Part 9/10 backtest reporting.    |
//+------------------------------------------------------------------+
double OnTester()
{
   return 0.0;
}
