//+------------------------------------------------------------------+
//|                                           CLSAgent_Journal.mqh   |
//|   CLS Agent v2.4+ - Memory / Journal - Part 8                    |
//|                                                                    |
//|   Rule #9: every signal that reaches the Score Engine - accepted    |
//|   or rejected by any later stage - gets exactly one row here. This   |
//|   is the only complete record of what the EA *considered*; contrast   |
//|   BasketExecutor's own log (CLSAgent_BasketExecutor.mqh), which only   |
//|   fires for the broker-mechanics outcome of a signal Risk Engine        |
//|   already approved.                                                      |
//+------------------------------------------------------------------+
#ifndef CLSAGENT_JOURNAL_MQH
#define CLSAGENT_JOURNAL_MQH

#include "../Core/CLSAgent_Types.mqh"
#include "../Core/CLSAgent_Utils.mqh"
#include "CLSAgent_CsvWriter.mqh"

//+------------------------------------------------------------------+
//| rejectReason picks whichever stage actually rejected the signal -    |
//| Score Engine's if it never got accepted, Risk Engine's otherwise     |
//| (a signal the Score Engine accepted can still be rejected by Risk).  |
//+------------------------------------------------------------------+
void CLS_Journal_LogSignal(const SSetupContext &ctx, const SSetupSignal &signal, const SScoreResult &score,
                            const SRiskDecision &risk, const bool executed, const ulong ticket)
{
   const ENUM_CLS_REJECT_REASON reason = (score.status != CLS_SIGNAL_ACCEPTED) ? score.rejectReason : risk.rejectReason;

   static const string header =
      "time,symbol,setup,direction,entry,sl,tp,score,scoreStatus,riskApproved,lots,rejectReason,executed,ticket";

   const string line = StringFormat("%s,%s,%s,%s,%.5f,%.5f,%.5f,%.1f,%s,%s,%.2f,%s,%s,%I64u",
      TimeToString(ctx.barTime, TIME_DATE | TIME_MINUTES), ctx.symbol, EnumToString(signal.setupType),
      CLS_DirectionToString(signal.direction), signal.entryPrice, signal.stopLoss, signal.takeProfit,
      score.score, EnumToString(score.status), (risk.isApproved ? "true" : "false"), risk.lotSize,
      CLS_RejectReasonToString(reason), (executed ? "true" : "false"), ticket);

   CLS_Csv_AppendLine("journal.csv", header, line);
}

#endif // CLSAGENT_JOURNAL_MQH
