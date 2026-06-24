//+------------------------------------------------------------------+
//|                                            CLSAgent_Types.mqh    |
//|   CLS Agent v2.4+ - Decision-Safe Contextual Liquidity Scalping  |
//|   Core / Types - Part 1                                          |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_TYPES_MQH
#define CLSAGENT_TYPES_MQH

//+------------------------------------------------------------------+
//| Enumerations                                                      |
//+------------------------------------------------------------------+

// Operating mode of the EA. The EA itself always decides; this only
// controls whether a decision is allowed to reach the broker.
enum ENUM_CLS_MODE
{
   CLS_MODE_SIGNAL_ONLY = 0,   // Analyze & log only, never sends orders
   CLS_MODE_SEMI_AUTO   = 1,   // Requires manual confirmation before sending
   CLS_MODE_AUTO_TRADE  = 2    // Fully automatic execution under Risk Engine rules
};

// Asset class, used to select per-class Score/Risk profiles (Rule #8).
enum ENUM_CLS_ASSET_CLASS
{
   CLS_ASSET_GOLD  = 0,
   CLS_ASSET_FOREX = 1
};

// Trade direction.
enum ENUM_CLS_DIRECTION
{
   CLS_DIR_NONE = 0,
   CLS_DIR_BUY  = 1,
   CLS_DIR_SELL = -1
};

// Setup identifiers, implemented in Part 3.
enum ENUM_CLS_SETUP_TYPE
{
   CLS_SETUP_NONE               = 0,
   CLS_SETUP_A_ASIAN_SWEEP      = 1,
   CLS_SETUP_B_DAILY_HUNT       = 2,
   CLS_SETUP_C_FVG_FILL         = 3,
   CLS_SETUP_D_BMS_CONTINUATION = 4
};

// Trading session, implemented in Part 2.
enum ENUM_CLS_SESSION
{
   CLS_SESSION_OFF     = 0,
   CLS_SESSION_ASIAN    = 1,
   CLS_SESSION_LONDON   = 2,
   CLS_SESSION_NEWYORK  = 3,
   CLS_SESSION_OVERLAP  = 4
};

// ATR volatility regime, implemented in Part 2.
enum ENUM_CLS_ATR_REGIME
{
   CLS_ATR_REGIME_LOW      = 0,
   CLS_ATR_REGIME_NORMAL   = 1,
   CLS_ATR_REGIME_HIGH     = 2,
   CLS_ATR_REGIME_EXTREME  = 3
};

// Outcome of signal evaluation, implemented in Part 4.
enum ENUM_CLS_SIGNAL_STATUS
{
   CLS_SIGNAL_REJECTED = 0,
   CLS_SIGNAL_ACCEPTED = 1,
   CLS_SIGNAL_PENDING  = 2
};

// Reason a signal/order was rejected. Every value here must end up in the
// Journal (Part 8) per Rule #9 - both rejected and accepted signals are logged.
enum ENUM_CLS_REJECT_REASON
{
   CLS_REJECT_NONE            = 0,
   CLS_REJECT_SPREAD          = 1,
   CLS_REJECT_SESSION         = 2,
   CLS_REJECT_ATR_REGIME      = 3,
   CLS_REJECT_DAILY_LOSS      = 4,
   CLS_REJECT_SCORE_LOW       = 5,
   CLS_REJECT_BASKET_FULL     = 6,
   CLS_REJECT_LOSING_BASKET   = 7,
   CLS_REJECT_NEWS            = 8,
   CLS_REJECT_PERMISSION      = 9,
   CLS_REJECT_UNCONFIRMED_BAR = 10,
   CLS_REJECT_OTHER           = 99
};

// Log severity levels used by Core/Utils.
enum ENUM_CLS_LOG_LEVEL
{
   CLS_LOG_DEBUG   = 0,
   CLS_LOG_INFO    = 1,
   CLS_LOG_WARNING = 2,
   CLS_LOG_ERROR   = 3
};

//+------------------------------------------------------------------+
//| Data contracts between pipeline stages.                          |
//|                                                                    |
//| Part 1 only defines the shape of these structs so the EA shell    |
//| compiles and the pipeline stages have something concrete to pass  |
//| around. No module populates them with real values yet - that      |
//| starts in Part 2 (Context) through Part 7 (Position Manager).     |
//+------------------------------------------------------------------+

// Snapshot of one closed bar's market context - filled by Context Engine (Part 2).
struct SSetupContext
{
   string               symbol;
   ENUM_CLS_ASSET_CLASS assetClass;
   datetime             barTime;
   ENUM_CLS_SESSION     session;
   ENUM_CLS_ATR_REGIME  atrRegime;
   double               atrValue;
   double               spreadPoints;
   bool                 sessionAllowed;   // CLS_IsSessionTradeable(session)
   bool                 spreadAllowed;    // CLS_SpreadBuffer_IsAcceptable(...)
   bool                 atrRegimeAllowed; // CLS_IsATRRegimeTradeable(atrRegime)
   bool                 isContextValid;   // all market reads succeeded (history/handles ready)

   SSetupContext()
   {
      symbol           = "";
      assetClass       = CLS_ASSET_FOREX;
      barTime          = 0;
      session          = CLS_SESSION_OFF;
      atrRegime        = CLS_ATR_REGIME_NORMAL;
      atrValue         = 0.0;
      spreadPoints     = 0.0;
      sessionAllowed   = false;
      spreadAllowed    = false;
      atrRegimeAllowed = false;
      isContextValid   = false;
   }
};

// Output of the Setup Detector - filled in Part 3.
struct SSetupSignal
{
   ENUM_CLS_SETUP_TYPE setupType;
   ENUM_CLS_DIRECTION  direction;
   datetime            barTime;
   double              entryPrice;
   double              stopLoss;
   double              takeProfit;
   bool                isValid;

   SSetupSignal()
   {
      setupType  = CLS_SETUP_NONE;
      direction  = CLS_DIR_NONE;
      barTime    = 0;
      entryPrice = 0.0;
      stopLoss   = 0.0;
      takeProfit = 0.0;
      isValid    = false;
   }
};

// Output of the Score Engine - filled in Part 4.
struct SScoreResult
{
   double                  score;
   ENUM_CLS_SIGNAL_STATUS  status;
   ENUM_CLS_REJECT_REASON  rejectReason;

   SScoreResult()
   {
      score        = 0.0;
      status       = CLS_SIGNAL_REJECTED;
      rejectReason = CLS_REJECT_NONE;
   }
};

// Output of the Risk Engine - filled in Part 5.
struct SRiskDecision
{
   bool                    isApproved;
   double                  lotSize;
   double                  basketRiskPercent;
   ENUM_CLS_REJECT_REASON  rejectReason;

   SRiskDecision()
   {
      isApproved        = false;
      lotSize           = 0.0;
      basketRiskPercent = 0.0;
      rejectReason      = CLS_REJECT_NONE;
   }
};

// One basket's aggregate state - filled in Parts 6-7. Risk is tracked as
// totalRiskPercent for the whole basket (Rule #3/#4), never per order.
struct SBasketInfo
{
   long                basketId;
   ENUM_CLS_DIRECTION  direction;
   int                 ordersCount;
   double              totalLots;
   double              totalRiskPercent;
   double              averageEntry;
   datetime            openTime;
   bool                isLosing;

   SBasketInfo()
   {
      basketId         = 0;
      direction        = CLS_DIR_NONE;
      ordersCount      = 0;
      totalLots        = 0.0;
      totalRiskPercent = 0.0;
      averageEntry     = 0.0;
      openTime         = 0;
      isLosing         = false;
   }
};

#endif // CLSAGENT_TYPES_MQH
