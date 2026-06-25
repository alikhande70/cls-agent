//+------------------------------------------------------------------+
//|                                       CLSAgent_Constants.mqh     |
//|   CLS Agent v2.4+ - Decision-Safe Contextual Liquidity Scalping  |
//|   Core / Constants - Part 1                                      |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_CONSTANTS_MQH
#define CLSAGENT_CONSTANTS_MQH

#define CLS_AGENT_NAME       "CLS Agent"
#define CLS_AGENT_VERSION    "2.5.0"
#define CLS_AGENT_FULL_NAME  "Decision-Safe Contextual Liquidity Scalping Agent"

//--- Non-negotiable safety rules -----------------------------------------
// These are compile-time constants, not inputs, so they can never be
// toggled off by a configuration mistake.
#define CLS_NO_ADD_TO_LOSING_BASKET true   // Rule #5: never add to a losing basket
#define CLS_LLM_CAN_SEND_ORDERS     false  // Rule #1: LLM never sends orders
#define CLS_ENTRY_REQUIRES_CLOSED_BAR true // Rule #6: confirm on closed candle only

//--- Sizing / structural limits ------------------------------------------
#define CLS_MAX_ORDERS_PER_BASKET_HARDCAP 5
#define CLS_MAX_SETUPS                     5
#define CLS_MAX_SYMBOLS                    4

//--- Magic number layout ---------------------------------------------------
// Final magic = CLS_MAGIC_BASE + per-setup offset, so every order can be
// traced back to the setup that created it from the magic number alone.
#define CLS_MAGIC_BASE                 10240
#define CLS_MAGIC_OFFSET_SETUP_A       0
#define CLS_MAGIC_OFFSET_SETUP_B       1
#define CLS_MAGIC_OFFSET_SETUP_C       2
#define CLS_MAGIC_OFFSET_SETUP_D       3
#define CLS_MAGIC_OFFSET_SETUP_E       4

//--- Files\CLSAgent\ subfolders (relative to the terminal's MQL5\Files\) --
#define CLS_FILES_LOGS_DIR     "CLSAgent\\logs\\"
#define CLS_FILES_REPORTS_DIR  "CLSAgent\\reports\\"
#define CLS_FILES_STATE_DIR    "CLSAgent\\state\\"

//--- Numeric tolerances ----------------------------------------------------
#define CLS_PRICE_EPSILON   0.0000001
#define CLS_SCORE_MIN        0.0
#define CLS_SCORE_MAX        100.0

#endif // CLSAGENT_CONSTANTS_MQH
