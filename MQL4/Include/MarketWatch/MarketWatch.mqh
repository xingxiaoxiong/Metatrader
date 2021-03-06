//+------------------------------------------------------------------+
//|                                                  MarketWatch.mqh |
//|                                 Copyright © 2017, Matthew Kastor |
//|                                 https://github.com/matthewkastor |
//+------------------------------------------------------------------+
#property copyright "Matthew Kastor"
#property link      "https://github.com/matthewkastor"
#property strict

#include <stdlib.mqh>
#include <Generic\ArrayList.mqh>
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class MarketWatch
  {
public:
   static bool       DoesSymbolExist(string symbol,bool useMarketWatchOnly);
   static bool       IsSymbolWatched(string symbolName);
   static bool       AddSymbolToMarketWatch(string symbolName);
   static int        GetWatchedSymbols(string &arr[]);
   static bool       RemoveSymbolFromMarketWatch(string symbolName);
   static bool       LoadSymbolHistory(string symbol,ENUM_TIMEFRAMES timeframe,bool force);
   static long       OpenChart(string symbol,ENUM_TIMEFRAMES timeframe);
   static long       OpenChartIfMissing(string symbol,ENUM_TIMEFRAMES timeframe);
   static long       GetChartId(string symbol,ENUM_TIMEFRAMES timeframe);
   static double     GetPoints(string symbol);
   static double     GetAsk(string symbol);
   static double     GetBid(string symbol);
   static double     GetSpread(string symbol);
   static bool       GetTick(string symbol,MqlTick &tick);
   static string     GetTickFlagDescription(uint flag);
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
static string MarketWatch::GetTickFlagDescription(uint flag)
  {
   string str;

   if((flag  &TICK_FLAG_BID)==TICK_FLAG_BID)
     {
      str+="Bid Update. ";
     }
   if((flag  &TICK_FLAG_ASK)==TICK_FLAG_ASK)
     {
      str+="Ask Update. ";
     }
   if((flag  &TICK_FLAG_LAST)==TICK_FLAG_LAST)
     {
      str+="Last Deal Price Update. ";
     }
   if((flag  &TICK_FLAG_VOLUME)==TICK_FLAG_VOLUME)
     {
      str+="Volume Update. ";
     }
   if((flag  &TICK_FLAG_BUY)==TICK_FLAG_BUY)
     {
      str+="Buy Order Processed. ";
     }
   if((flag  &TICK_FLAG_SELL)==TICK_FLAG_SELL)
     {
      str+="Sell Order Processed. ";
     }

   str=StringTrimRight(str);
   return str;
  };
//+------------------------------------------------------------------+
//|Doesn't return the tick, no. You supply the empty tick and get a
//|boolean value indicating whether or not you MIGHT be able to trust
//|the data in the tick you supplied. Becaue MQL is shit.
//+------------------------------------------------------------------+
static bool MarketWatch::GetTick(string symbol,MqlTick &tick)
  {
   return SymbolInfoTick(symbol,tick);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
static double MarketWatch::GetSpread(string symbol)
  {
   return MarketInfo(symbol,MODE_SPREAD);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
static double MarketWatch::GetAsk(string symbol)
  {
   return MarketInfo(symbol,MODE_ASK);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
static double MarketWatch::GetBid(string symbol)
  {
   return MarketInfo(symbol,MODE_BID);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
static double MarketWatch::GetPoints(string symbol)
  {
   return MarketInfo(symbol,MODE_POINT);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
static int MarketWatch::GetWatchedSymbols(string &arr[])
  {
   int ct=SymbolsTotal(true);
   ArrayResize(arr,ct,0);
   for(int i=0; i<ct; i++)
     {
      arr[i]=SymbolName(i,true);
     }
   return ArraySize(arr);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
static bool MarketWatch::DoesSymbolExist(string symbol,bool useMarketWatchOnly=false)
  {
   bool out=false;
   int ct=SymbolsTotal(useMarketWatchOnly);
   for(int i=0; i<ct; i++)
     {
      if(symbol==SymbolName(i,useMarketWatchOnly))
        {
         out=true;
        }
     }
   return out;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool MarketWatch::IsSymbolWatched(string symbolName)
  {
   return DoesSymbolExist(symbolName,true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool MarketWatch::AddSymbolToMarketWatch(string symbolName)
  {
   bool result=false;
   if(IsSymbolWatched(symbolName))
     {
      result=true;
     }
   else if(DoesSymbolExist(symbolName))
     {
      result=SymbolSelect(symbolName,true);
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool MarketWatch::RemoveSymbolFromMarketWatch(string symbolName)
  {
   bool result=false;
   if(!IsSymbolWatched(symbolName))
     {
      result=true;
     }
   else
     {
      result=SymbolSelect(symbolName,false);
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool MarketWatch::LoadSymbolHistory(string symbol,ENUM_TIMEFRAMES timeframe,bool force)
  {
   MqlRates r[];
   int ct= ArrayCopyRates(r,symbol,timeframe);
   if(ct>=0)
     {
      return true;
     }

   bool out=false;
   int error=GetLastError();
   if(error==4066 && force)
     {
      for(int i=0;i<30; i++)
        {
         Sleep(1000);
         ct=ArrayCopyRates(r,symbol,timeframe);
         if(ct<0)
           {
            //---- check the current bar time
            datetime timestamp=r[0].time;
            if(timestamp>=(TimeCurrent()-(timeframe*60)))
              {
               out=true;
               break;
              }
           }
        }
     }
   return out;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
long MarketWatch::OpenChart(string symbol,ENUM_TIMEFRAMES timeframe)
  {
   long chartId=ChartOpen(symbol,timeframe);
   if(chartId==0)
     {
      Print("the chart didn't open, error: ",GetLastError());
      Print(ErrorDescription(GetLastError()));
      chartId=(-1);
     }
   return chartId;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
long MarketWatch::OpenChartIfMissing(string symbol,ENUM_TIMEFRAMES timeframe)
  {
   long chartId=GetChartId(symbol,timeframe);
   if(chartId==-1)
     {
      chartId=OpenChart(symbol,timeframe);
     }
   return chartId;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
long MarketWatch::GetChartId(string symbol,ENUM_TIMEFRAMES timeframe)
  {
   long chartId=ChartFirst();
   while(chartId>=0)
     {
      if(symbol==ChartSymbol(chartId) && timeframe==ChartPeriod(chartId))
        {
         break;
        }
      chartId=ChartNext(chartId);
     }
   return chartId;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
