//+------------------------------------------------------------------+
//|                                    CLSAgent_StrategyProfile.mqh  |
//|   CLS Agent v2.4+ - Core / Strategy Profile - P1 scaffolding     |
//|                                                                    |
//|   P1 infrastructure ONLY. Provides the strategy-profile selector  |
//|   resolver that later QuickProfitMode phases will consume. In P1   |
//|   this changes NO trading behavior:                                |
//|                                                                    |
//|   - Default profile is CLS_PROFILE_BASELINE (current behavior).    |
//|   - QuickProfitMode is future/optional and not implemented yet.    |
//|   - Every QuickProfit input is inert; for BASELINE the resolver    |
//|     returns fully neutral settings, and nothing in the decision,   |
//|     risk, execution, exit, or reporting paths reads these values   |
//|     in P1.                                                         |
//|                                                                    |
//|   The resolver exists so P2+ (profit-lock, faster trailing, lower  |
//|   thresholds, frequency guards) can be added behind the profile in |
//|   separate, owner-approved, gate-based phases without reshaping the |
//|   EA. It never sends orders and never bypasses Decision/Risk/       |
//|   Execution. See docs/QUICKPROFIT_MODE_DESIGN.md.                   |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_STRATEGYPROFILE_MQH
#define CLSAGENT_STRATEGYPROFILE_MQH

#include "CLSAgent_Types.mqh"
#include "CLSAgent_Inputs.mqh"

//+------------------------------------------------------------------+
//| Effective, resolved settings for the active strategy profile.      |
//| For BASELINE every field is neutral (0 / false) so no later        |
//| consumer could change behavior. QuickProfit fields are captured     |
//| from inputs only when the QuickProfit profile is active - and even  |
//| then, P1 has no consumer wired in yet.                              |
//+------------------------------------------------------------------+
struct SStrategyProfileSettings
{
   ENUM_CLS_STRATEGY_PROFILE profile;
   bool   quickProfitActive;          // true only when profile == CLS_PROFILE_QUICK_PROFIT

   // --- QuickProfit-only knobs (inert in P1; neutral in BASELINE) ---
   double scoreDelta;                 // min-score offset (<= 0); 0 = no change
   int    maxTradesPerDay;            // 0 = unlimited
   int    maxTradesPerSymbolPerDay;   // 0 = unlimited
   int    maxConcurrentPositions;     // 0 = unlimited
   int    cooldownAfterLossMinutes;   // 0 = off
   int    cooldownAfterWinMinutes;    // 0 = off
   double minProfitMoney;             // 0 = off
   double lockMoney;                  // 0 = off
   double stepMoney;                  // 0 = off

   SStrategyProfileSettings()
   {
      profile                  = CLS_PROFILE_BASELINE;
      quickProfitActive        = false;
      scoreDelta               = 0.0;
      maxTradesPerDay          = 0;
      maxTradesPerSymbolPerDay = 0;
      maxConcurrentPositions   = 0;
      cooldownAfterLossMinutes = 0;
      cooldownAfterWinMinutes  = 0;
      minProfitMoney           = 0.0;
      lockMoney                = 0.0;
      stepMoney                = 0.0;
   }
};

// Populated once in OnInit(); read by future QuickProfit phases. Unused by any
// trading-decision path in P1.
SStrategyProfileSettings g_StrategyProfile;

//+------------------------------------------------------------------+
//| Resolve the active profile into effective settings.                |
//|                                                                    |
//| BASELINE: returns the default (all-neutral) struct, guaranteeing    |
//| identical behavior to current main regardless of the QuickProfit    |
//| input values.                                                       |
//|                                                                    |
//| QUICK_PROFIT: captures the QuickProfit inputs into the struct so a  |
//| later phase can consume them. P1 wires NO consumer, so selecting    |
//| this profile still changes no trading behavior on its own.          |
//+------------------------------------------------------------------+
SStrategyProfileSettings CLS_ResolveStrategyProfile()
{
   SStrategyProfileSettings s; // ctor = neutral / BASELINE-equivalent
   s.profile           = InpStrategyProfile;
   s.quickProfitActive = (InpStrategyProfile == CLS_PROFILE_QUICK_PROFIT);

   if(!s.quickProfitActive)
      return s; // BASELINE: neutral settings, current behavior preserved exactly

   // QuickProfit profile selected: capture inputs for future phases to consume.
   // (No P1 consumer reads these yet - selecting the profile is still inert.)
   s.scoreDelta               = InpQuickProfitScoreDelta;
   s.maxTradesPerDay          = InpQuickProfitMaxTradesPerDay;
   s.maxTradesPerSymbolPerDay = InpQuickProfitMaxTradesPerSymbolPerDay;
   s.maxConcurrentPositions   = InpQuickProfitMaxConcurrentPositions;
   s.cooldownAfterLossMinutes = InpQuickProfitCooldownAfterLossMinutes;
   s.cooldownAfterWinMinutes  = InpQuickProfitCooldownAfterWinMinutes;
   s.minProfitMoney           = InpQuickProfitMinProfitMoney;
   s.lockMoney                = InpQuickProfitLockMoney;
   s.stepMoney                = InpQuickProfitStepMoney;
   return s;
}

#endif // CLSAGENT_STRATEGYPROFILE_MQH
