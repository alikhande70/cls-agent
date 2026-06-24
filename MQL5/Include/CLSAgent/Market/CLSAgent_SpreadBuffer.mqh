//+------------------------------------------------------------------+
//|                                       CLSAgent_SpreadBuffer.mqh  |
//|   CLS Agent v2.4+ - Market / Spread Buffer - Part 2              |
//|                                                                    |
//|   Rolling average of recent tick spreads. Rule #7 requires spread |
//|   to be checked before every entry; averaging a few samples avoids |
//|   rejecting/accepting a signal because of one freak one-tick spike.|
//+------------------------------------------------------------------+
#ifndef CLSAGENT_SPREADBUFFER_MQH
#define CLSAGENT_SPREADBUFFER_MQH

#include "../Core/CLSAgent_Inputs.mqh"

struct SSpreadBuffer
{
   double samples[];
   int    count;
   int    capacity;
   int    nextIndex;
};

SSpreadBuffer g_SpreadBuf;

//+------------------------------------------------------------------+
//| Call once from OnInit().                                          |
//+------------------------------------------------------------------+
void CLS_SpreadBuffer_Init()
{
   g_SpreadBuf.capacity = MathMax(1, InpSpreadBufferSamples);
   ArrayResize(g_SpreadBuf.samples, g_SpreadBuf.capacity);
   ArrayInitialize(g_SpreadBuf.samples, 0.0);
   g_SpreadBuf.count     = 0;
   g_SpreadBuf.nextIndex = 0;
}

//+------------------------------------------------------------------+
//| Call on every tick (not gated by bar-close) so the average always |
//| reflects current market conditions by the time a bar closes.      |
//+------------------------------------------------------------------+
void CLS_SpreadBuffer_AddSample(const string symbol)
{
   const double spreadPoints = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD);

   g_SpreadBuf.samples[g_SpreadBuf.nextIndex] = spreadPoints;
   g_SpreadBuf.nextIndex = (g_SpreadBuf.nextIndex + 1) % g_SpreadBuf.capacity;
   if(g_SpreadBuf.count < g_SpreadBuf.capacity)
      g_SpreadBuf.count++;
}

double CLS_SpreadBuffer_Average()
{
   if(g_SpreadBuf.count == 0)
      return 0.0;

   double sum = 0.0;
   for(int i = 0; i < g_SpreadBuf.count; i++)
      sum += g_SpreadBuf.samples[i];

   return sum / g_SpreadBuf.count;
}

//+------------------------------------------------------------------+
//| False until the buffer is full, so the very first ticks after     |
//| EA start can never pass the spread filter on stale/partial data.   |
//+------------------------------------------------------------------+
bool CLS_SpreadBuffer_IsAcceptable(const int maxSpreadPoints)
{
   if(g_SpreadBuf.count < g_SpreadBuf.capacity)
      return false;

   return CLS_SpreadBuffer_Average() <= (double)maxSpreadPoints;
}

#endif // CLSAGENT_SPREADBUFFER_MQH
