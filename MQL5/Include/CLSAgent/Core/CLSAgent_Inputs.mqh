//+------------------------------------------------------------------+
//|                                           CLSAgent_Inputs.mqh    |
//|   CLS Agent v2.4+ - Decision-Safe Contextual Liquidity Scalping  |
//|   Core / Inputs - Part 1                                         |
//|                                                                    |
//|   All EA inputs live here so every module's tunables are visible  |
//|   in one place, grouped by the module that consumes them.         |
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
input int             InpMaxSlippagePoints = 20;                   // Max allowed slippage, in points

input group "==== CLS Agent | Symbol & Asset Class ===="
input ENUM_CLS_ASSET_CLASS InpAssetClass  = CLS_ASSET_GOLD;        // Fallback asset class if symbol auto-detection is inconclusive
input string               InpGoldAliases = "XAUUSD,XAUUSDm,GOLD"; // Broker-specific spellings recognized as Gold

input group "==== CLS Agent | Session Filter ===="
input bool InpUseAsianSession        = true;  // Allow trading during Asian session
input bool InpUseLondonSession       = true;  // Allow trading during London session
input bool InpUseNewYorkSession      = true;  // Allow trading during New York session
input int  InpSessionAsianStartHour  = 0;     // Asian session start hour (broker time)
input int  InpSessionAsianEndHour    = 7;     // Asian session end hour (broker time)
input int  InpSessionLondonStartHour = 7;     // London session start hour (broker time)
input int  InpSessionLondonEndHour   = 16;    // London session end hour (broker time)
input int  InpSessionNewYorkStartHour= 12;    // New York session start hour (broker time)
input int  InpSessionNewYorkEndHour  = 21;    // New York session end hour (broker time)

input group "==== CLS Agent | Spread & ATR Filter ===="
input int              InpMaxSpreadPointsGold  = 250;        // Max spread allowed for Gold, in points
input int              InpMaxSpreadPointsForex = 20;         // Max spread allowed for Forex majors, in points
input int              InpSpreadBufferSamples   = 10;         // Number of ticks averaged for the spread filter
input int              InpATRPeriod             = 14;         // ATR period used for regime detection
input ENUM_TIMEFRAMES  InpATRTimeframe          = PERIOD_H1;  // Timeframe used for ATR regime detection
input double           InpATRRegimeHighMult     = 1.5;        // ATR multiple above average => HIGH regime
input double           InpATRRegimeExtremeMult  = 2.5;        // ATR multiple above average => EXTREME regime (blocks entries)

input group "==== CLS Agent | Setup Detection (Part 3) ===="
input int    InpSwingLookbackBars     = 20;   // Bars scanned back when searching for a swing high/low pivot
input int    InpFractalWingBars       = 2;    // Bars required on each side to confirm a fractal swing pivot
input double InpStopLossATRMultiplier = 1.2;  // Stop-loss distance = ATR * this multiplier
input double InpTakeProfitRMultiple   = 1.5;  // Take-profit distance = stop distance * this R-multiple
input double InpSweepMinPierceATRFrac = 0.15; // Min pierce beyond a swept level, as a fraction of ATR, to count as a real sweep
input double InpFVGMinSizeATRFrac     = 0.10; // Min Fair Value Gap size, as a fraction of ATR, to be tradeable
input double InpBMSMinBodyATRPct      = 0.50; // Min breakout candle body size, as a fraction of ATR, to confirm a valid BMS break

input group "==== CLS Agent | Score Engine ===="
input double InpMinScoreToTradeGold  = 65.0; // Minimum multiplicative score required for Gold
input double InpMinScoreToTradeForex = 60.0; // Minimum multiplicative score required for Forex majors
input bool   InpEnableSetupA         = true; // Enable Setup A - Asian Sweep
input bool   InpEnableSetupB         = true; // Enable Setup B - Daily Hunt
input bool   InpEnableSetupC         = true; // Enable Setup C - FVG Fill
input bool   InpEnableSetupD         = true; // Enable Setup D - BMS Continuation

input group "==== CLS Agent | Risk Engine ===="
input double InpBasketRiskPercent   = 0.30;  // Total basket risk, % of equity (NOT per order - Rule #3)
input int    InpMaxOrdersPerBasket  = 2;     // Max number of orders inside one basket
input double InpMaxDailyLossPercent = 1.00;  // Max daily loss, % of equity, before trading halts for the day
input bool   InpSuperBurst          = false; // Allow oversized bursts beyond MaxOrdersPerBasket (advanced, disabled by default)

input group "==== CLS Agent | News Guard (manual input) ===="
input bool   InpNewsGuardEnabled    = true; // Block entries around manually scheduled news windows
input string InpNewsBlockWindowsRaw = "";   // "YYYY.MM.DD HH:MM-HH:MM;..." manual high-impact news windows

input group "==== CLS Agent | Basket Execution ===="
input int InpOrderRetryCount   = 3;   // Broker rejection retry attempts
input int InpOrderRetryDelayMs = 200; // Delay between retries, in milliseconds

input group "==== CLS Agent | Position Management (Part 7) ===="
input bool   InpUseBreakeven              = true;  // Move SL to breakeven once price reaches InpBreakevenTriggerR
input double InpBreakevenTriggerR         = 1.0;   // Profit, in R-multiples of ATR*InpStopLossATRMultiplier, that triggers breakeven
input int    InpBreakevenOffsetPoints     = 20;    // Points beyond entry to lock in at breakeven (covers spread/commission)
input bool   InpUsePartialExit            = true;  // Close part of the position once price reaches InpPartialExitTriggerR
input double InpPartialExitTriggerR       = 1.0;   // Profit, in R-multiples, that triggers the one-shot partial exit
input double InpPartialExitPercent        = 50.0;  // % of current volume closed by the partial exit
input bool   InpUseTrailingStop           = true;  // Trail the stop once price reaches InpTrailingStopTriggerR
input double InpTrailingStopTriggerR      = 1.5;   // Profit, in R-multiples, that activates trailing
input double InpTrailingStopATRMultiplier = 1.0;   // Trailing distance behind price = ATR * this multiplier
input int    InpTrailingStopStepPoints    = 50;    // Min SL improvement, in points, before sending another modify

input group "==== CLS Agent | Logging & Debug ===="
input ENUM_CLS_LOG_LEVEL InpLogLevel      = CLS_LOG_INFO; // Minimum severity printed to the Experts log
input bool                InpLogToFile     = true;          // Mirror log lines to Files\CLSAgent\logs\
input bool                InpShowDebugPanel= true;          // Draw on-chart debug panel

#endif // CLSAGENT_INPUTS_MQH
