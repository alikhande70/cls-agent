//+------------------------------------------------------------------+
//|                                           CLSAgent_Inputs.mqh    |
//|   CLS Agent v2.4+ - Decision-Safe Contextual Liquidity Scalping  |
//|   Core / Inputs - Part 1                                         |
//|                                                                    |
//|   All EA inputs live here so every module's tunables are visible  |
//|   in one place. Inputs whose consuming module does not exist yet  |
//|   are marked "(used from Part N)" - they are safe to configure    |
//|   now, they simply have no effect until that part is added.       |
//|                                                                    |
//|   NOTE: NoAddToLosingBasket is intentionally NOT an input - Rule  |
//|   #5 requires it to always be true, so it is a hardcoded constant |
//|   in CLSAgent_Constants.mqh (CLS_NO_ADD_TO_LOSING_BASKET) instead  |
//|   of a switch someone could accidentally turn off.                |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_INPUTS_MQH
#define CLSAGENT_INPUTS_MQH

input group "==== CLS Agent | General ===="
input ENUM_CLS_MODE   InpMode              = CLS_MODE_SIGNAL_ONLY; // Operating mode
input bool            InpAutoTrade         = false;                // Master switch - both this AND Mode=AUTO_TRADE are required to send real orders
input ulong           InpMagicNumber       = CLS_MAGIC_BASE;       // Magic number base for this chart's symbol
input int             InpMaxSlippagePoints = 20;                   // Max allowed slippage, in points (used from Part 6)

input group "==== CLS Agent | Symbol & Asset Class ===="
input ENUM_CLS_ASSET_CLASS InpAssetClass  = CLS_ASSET_GOLD;        // Fallback asset class if symbol auto-detection is inconclusive
input string               InpGoldAliases = "XAUUSD,XAUUSDm,GOLD"; // Broker-specific spellings recognized as Gold

input group "==== CLS Agent | Session Filter (used from Part 2) ===="
input bool InpUseAsianSession        = true;  // Allow trading during Asian session
input bool InpUseLondonSession       = true;  // Allow trading during London session
input bool InpUseNewYorkSession      = true;  // Allow trading during New York session
input int  InpSessionAsianStartHour  = 0;     // Asian session start hour (broker time)
input int  InpSessionAsianEndHour    = 7;     // Asian session end hour (broker time)
input int  InpSessionLondonStartHour = 7;     // London session start hour (broker time)
input int  InpSessionLondonEndHour   = 16;    // London session end hour (broker time)
input int  InpSessionNewYorkStartHour= 12;    // New York session start hour (broker time)
input int  InpSessionNewYorkEndHour  = 21;    // New York session end hour (broker time)

input group "==== CLS Agent | Spread & ATR Filter (used from Part 2) ===="
input int              InpMaxSpreadPointsGold  = 250;        // Max spread allowed for Gold, in points
input int              InpMaxSpreadPointsForex = 20;         // Max spread allowed for Forex majors, in points
input int              InpSpreadBufferSamples   = 10;         // Number of ticks averaged for the spread filter
input int              InpATRPeriod             = 14;         // ATR period used for regime detection
input ENUM_TIMEFRAMES  InpATRTimeframe          = PERIOD_H1;  // Timeframe used for ATR regime detection
input double           InpATRRegimeHighMult     = 1.5;        // ATR multiple above average => HIGH regime
input double           InpATRRegimeExtremeMult  = 2.5;        // ATR multiple above average => EXTREME regime (blocks entries)

input group "==== CLS Agent | Score Engine (used from Part 4) ===="
input double InpMinScoreToTradeGold  = 65.0; // Minimum multiplicative score required for Gold
input double InpMinScoreToTradeForex = 60.0; // Minimum multiplicative score required for Forex majors
input bool   InpEnableSetupA         = true; // Enable Setup A - Asian Sweep
input bool   InpEnableSetupB         = true; // Enable Setup B - Daily Hunt
input bool   InpEnableSetupC         = true; // Enable Setup C - FVG Fill
input bool   InpEnableSetupD         = true; // Enable Setup D - BMS Continuation

input group "==== CLS Agent | Risk Engine (used from Part 5) ===="
input double InpBasketRiskPercent   = 0.30;  // Total basket risk, % of equity (NOT per order - Rule #3)
input int    InpMaxOrdersPerBasket  = 2;     // Max number of orders inside one basket
input double InpMaxDailyLossPercent = 1.00;  // Max daily loss, % of equity, before trading halts for the day
input bool   InpSuperBurst          = false; // Allow oversized bursts beyond MaxOrdersPerBasket (advanced, disabled by default)

input group "==== CLS Agent | News Guard (manual input, used from Part 5) ===="
input bool   InpNewsGuardEnabled    = true; // Block entries around manually scheduled news windows
input string InpNewsBlockWindowsRaw = "";   // "YYYY.MM.DD HH:MM-HH:MM;..." manual high-impact news windows

input group "==== CLS Agent | Basket Execution (used from Part 6) ===="
input int InpOrderRetryCount   = 3;   // Broker rejection retry attempts
input int InpOrderRetryDelayMs = 200; // Delay between retries, in milliseconds

input group "==== CLS Agent | Logging & Debug ===="
input ENUM_CLS_LOG_LEVEL InpLogLevel      = CLS_LOG_INFO; // Minimum severity printed to the Experts log
input bool                InpLogToFile     = true;          // Mirror log lines to Files\CLSAgent\logs\ (used from Part 8)
input bool                InpShowDebugPanel= true;          // Draw on-chart debug panel (used from Part 9)

#endif // CLSAGENT_INPUTS_MQH
