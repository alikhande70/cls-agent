//+------------------------------------------------------------------+
//|                                                  CLSAgent.mq5    |
//|         CLS Agent v2.4+ - Decision-Safe Contextual Liquidity     |
//|                          Scalping Agent                          |
//|                                                                    |
//|   Part 1: Project Skeleton + Core Types + Inputs + Constants +    |
//|           Main EA Shell.                                          |
//|                                                                    |
//|   This file only wires the EA lifecycle (OnInit/OnTick/OnDeinit)   |
//|   and lays out the pipeline stages as named stubs. Parts 2-9       |
//|   replace each stub with a real module call - the call sites and   |
//|   their order will not change.                                     |
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

//+------------------------------------------------------------------+
//| Pipeline stage stubs - one per box in the architecture diagram.   |
//| Bodies are intentionally empty in Part 1; Parts 2-9 fill them in. |
//+------------------------------------------------------------------+
void Stage_ContextEngine_STUB(const SSetupContext &ctx)    { /* Part 2: Market/SymbolProfile, TimeSession, Indicators, SpreadBuffer, ATRRegime */ }
void Stage_SetupDetector_STUB(const SSetupSignal &signal)  { /* Part 3: Strategy/SetupDetector + Setup A/B/C/D */ }
void Stage_ScoreEngine_STUB(const SScoreResult &score)     { /* Part 4: Strategy/ScoreEngine + DecisionEngine */ }
void Stage_RiskEngine_STUB(const SRiskDecision &risk)      { /* Part 5: Risk/RiskEngine, BasketRisk, LotCalculator, DailyLimits */ }
void Stage_BasketExecution_STUB(const SBasketInfo &basket) { /* Part 6: Execution/OrderSender, BasketExecutor */ }
void Stage_PositionManager_STUB()                          { /* Part 7: Execution/PositionManager, PartialExit, Trailing */ }
void Stage_JournalMemory_STUB()                            { /* Part 8: Memory/Journal, TradeLog, BasketLog, PerformanceStats */ }
void Stage_ReportLLMReview_STUB()                           { /* Part 9: Reports/DebugPanel, BacktestReport, ExportCSV */ }

//+------------------------------------------------------------------+
//| Resolve Gold vs Forex from the chart symbol and InpGoldAliases.   |
//+------------------------------------------------------------------+
ENUM_CLS_ASSET_CLASS ResolveAssetClass()
{
   string aliases[];
   const int n   = CLS_SplitCsv(InpGoldAliases, aliases);
   const string sym = _Symbol;

   for(int i = 0; i < n; i++)
   {
      if(StringLen(aliases[i]) > 0 && StringFind(sym, aliases[i]) >= 0)
         return CLS_ASSET_GOLD;
   }
   return CLS_ASSET_FOREX;
}

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
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   g_LogMinLevel = (int)InpLogLevel;

   if(!ValidateInputs())
      return INIT_PARAMETERS_INCORRECT;

   const ENUM_CLS_ASSET_CLASS detectedClass = ResolveAssetClass();
   CLS_State_Init(_Symbol, detectedClass);

   CLS_Log(CLS_LOG_INFO, "Init", StringFormat(
      "%s v%s starting on %s | AssetClass=%s | Mode=%s | AutoTrade=%s",
      CLS_AGENT_FULL_NAME, CLS_AGENT_VERSION, _Symbol,
      (detectedClass == CLS_ASSET_GOLD ? "GOLD" : "FOREX"),
      EnumToString(InpMode),
      (InpAutoTrade ? "true" : "false")));

   CLS_Log(CLS_LOG_INFO, "Init", StringFormat(
      "Risk config: BasketRisk=%.2f%% MaxOrdersPerBasket=%d MaxDailyLoss=%.2f%% NoAddToLosingBasket=true (fixed)",
      InpBasketRiskPercent, InpMaxOrdersPerBasket, InpMaxDailyLossPercent));

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   CLS_Log(CLS_LOG_INFO, "Deinit", StringFormat("CLS Agent stopping. Reason code=%d", reason));
}

//+------------------------------------------------------------------+
//| Recompute whether the current Mode/AutoTrade combo permits orders. |
//| Even when this is true, Parts 5-6 (Risk Engine/Basket Execution)   |
//| still get the final veto - this flag only gates whether the EA is  |
//| allowed to attempt sending anything at all.                        |
//+------------------------------------------------------------------+
void RefreshTradingPermissionFlag()
{
   g_State.tradingAllowedByMode = (InpMode == CLS_MODE_AUTO_TRADE) && InpAutoTrade;
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   g_State.ticksProcessed++;

   if(CLS_State_RolloverDayIfNeeded())
      CLS_Log(CLS_LOG_INFO, "Tick", "New trading day detected, daily P/L baseline reset.");

   RefreshTradingPermissionFlag();

   // Rule #6: act only once per fully closed bar, never on the forming bar.
   if(!CLS_State_IsNewBar(_Symbol, PERIOD_CURRENT))
      return;

   CLS_Log(CLS_LOG_DEBUG, "Tick", StringFormat("New closed bar at %s on %s.",
           TimeToString(g_State.lastProcessedBarTime, TIME_DATE | TIME_MINUTES), _Symbol));

   // Pipeline shape only - default-constructed structs, no logic yet.
   // Parts 2-9 replace these stub calls with real module calls, in order.
   SSetupContext ctx;
   SSetupSignal  signal;
   SScoreResult  score;
   SRiskDecision risk;
   SBasketInfo   basket;

   Stage_ContextEngine_STUB(ctx);
   Stage_SetupDetector_STUB(signal);
   Stage_ScoreEngine_STUB(score);
   Stage_RiskEngine_STUB(risk);
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
