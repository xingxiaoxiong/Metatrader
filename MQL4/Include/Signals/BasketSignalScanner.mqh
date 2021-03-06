//+------------------------------------------------------------------+
//|                                          BasketSignalScanner.mqh |
//|                                 Copyright © 2017, Matthew Kastor |
//|                                 https://github.com/matthewkastor |
//+------------------------------------------------------------------+
#property copyright "Matthew Kastor"
#property link      "https://github.com/matthewkastor"
#property strict

#include <Common\Comparators.mqh>
#include <Common\BaseSymbolScanner.mqh>
#include <Common\OrderManager.mqh>
#include <Signals\SignalSet.mqh>
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class BasketSignalScanner : public BaseSymbolScanner
  {
private:
   Comparators       _compare;
   OrderManager      orderManager;
   SignalSet        *signalSet;
   bool              CanMarketOrderForOp(SignalResult &r);
   bool              CanMarketOrderStepForOp(SignalResult &r);
   bool              CanSendMarketOrder(SignalResult &r);
   bool              MustCloseOppositePositions(SignalResult &r);
   void              UpdateBuyExits(string symbol);
   void              UpdateSellExits(string symbol);
   void              UpdateExits(string symbol);
   void              UpdateExits(SignalResult *r,bool pinExits);
   void              FilterRisk(SignalResult &r);

public:
   bool              disableExitsBacksliding;
   bool              closePositionsOnOppositeSignal;
   double            lotSize;
   int               maxOpenOrders;
   double            gridStepSizeUp;
   double            gridStepSizeDown;
   bool              averageUp;
   bool              averageDown;
   bool              hedgingAllowed;
   double            filterRiskReward;
   void              BasketSignalScanner(
                                         SymbolSet *aSymbolSet,SignalSet *aSignalSet,
                                         double lotSize,bool allowExitsToBackslide,
                                         bool closePositionsOnOppositeSignal,
                                         int maxOpenOrderCount=1,
                                         double gridStepUpSizeInPricePercent=1.25,
                                         double gridStepDownSizeInPricePercent=1.25,
                                         bool averageUpStrategy=false,
                                         bool averageDownStrategy=false,
                                         bool allowHedging=false,
                                         double riskRewardFilter=1);
   void              PerSymbolAction(string symbol);
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void BasketSignalScanner::BasketSignalScanner(
                                              SymbolSet *aSymbolSet,SignalSet *aSignalSet,double aLotSize,
                                              bool allowExitsToBackslide,
                                              bool closeOrdersOnOppositeSignal,
                                              int maxOpenOrderCount=1,
                                              double gridStepUpSizeInPricePercent=1.25,
                                              double gridStepDownSizeInPricePercent=1.25,
                                              bool averageUpStrategy=false,
                                              bool averageDownStrategy=false,
                                              bool allowHedging=false,
                                              double riskRewardFilter=1):BaseSymbolScanner(aSymbolSet)
  {
   this.signalSet=aSignalSet;
   this.lotSize=aLotSize;
   this.disableExitsBacksliding=!allowExitsToBackslide;
   this.closePositionsOnOppositeSignal=closeOrdersOnOppositeSignal;
   this.maxOpenOrders=maxOpenOrderCount;
   this.gridStepSizeUp=gridStepUpSizeInPricePercent;
   this.gridStepSizeDown=gridStepDownSizeInPricePercent;
   this.averageUp=averageUpStrategy;
   this.averageDown=averageDownStrategy;
   this.hedgingAllowed=allowHedging;
   this.filterRiskReward=riskRewardFilter;
  }
//+------------------------------------------------------------------+
//|Returns true when there are no open positions or when all open    |
//|positions are of the given orderType                              |
//+------------------------------------------------------------------+
bool BasketSignalScanner::CanMarketOrderForOp(SignalResult &r)
  {
   if(!r.isSet)
     {
      return false;
     }
   bool result;

   result=true;
   if(this.hedgingAllowed==true)
     {
      return true;
     }
   if(r.orderType==OP_BUY && OrderManager::PairHighestPricePaid(r.symbol,OP_SELL)>0)
     {
      result=false;
     }
   if(r.orderType==OP_SELL && OrderManager::PairHighestPricePaid(r.symbol,OP_BUY)>0)
     {
      result=false;
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BasketSignalScanner::CanMarketOrderStepForOp(SignalResult &r)
  {
   if(!r.isSet)
     {
      return false;
     }
   if(!this.CanMarketOrderForOp(r))
     {
      return false;
     }

   bool send=false;

   if(r.orderType==OP_BUY)
     {
      if(this.averageUp==true)
        {
         send=send || (MarketWatch::GetAsk(r.symbol)>this.orderManager.GetHighStep(r.symbol,OP_BUY,this.gridStepSizeUp));
        }
      if(this.averageDown==true)
        {
         send=send || (MarketWatch::GetAsk(r.symbol)<this.orderManager.GetLowStep(r.symbol,OP_BUY,this.gridStepSizeDown));
        }
     }

   if(r.orderType==OP_SELL)
     {
      if(this.averageUp==true)
        {
         send=send || (MarketWatch::GetBid(r.symbol)<this.orderManager.GetLowStep(r.symbol,OP_SELL,this.gridStepSizeUp));
        }
      if(this.averageDown==true)
        {
         send=send || (MarketWatch::GetBid(r.symbol)>this.orderManager.GetHighStep(r.symbol,OP_SELL,this.gridStepSizeDown));
        }
     }

   return send;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BasketSignalScanner::CanSendMarketOrder(SignalResult &r)
  {
   if(!r.isSet)
     {
      return false;
     }
   bool result=false;
   double openPositionCount=this.orderManager.PairOpenPositionCount(r.symbol,TimeCurrent());
   if(openPositionCount<this.maxOpenOrders)
     {
      if(openPositionCount==0)
        {
         result=true;
        }
      else if(openPositionCount>0)
        {
         if(this.CanMarketOrderStepForOp(r))
           {
            result=true;
           }
        }
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BasketSignalScanner::MustCloseOppositePositions(SignalResult &r)
  {
   if(!r.isSet)
     {
      return false;
     }
   bool result=false;
   if(0==this.orderManager.PairOpenPositionCount(r.orderType,r.symbol,TimeCurrent()))
     {
      if(closePositionsOnOppositeSignal)
        {
         result=true;
        }
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void BasketSignalScanner::UpdateBuyExits(string symbol)
  {
   this.orderManager.NormalizeExits(
                                    symbol
                                    ,OP_BUY
                                    ,this.orderManager.PairHighestStopLoss(symbol,OP_BUY)
                                    ,this.orderManager.PairLowestTakeProfit(symbol,OP_BUY)
                                    ,false);

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void BasketSignalScanner::UpdateSellExits(string symbol)
  {
   this.orderManager.NormalizeExits(
                                    symbol
                                    ,OP_SELL
                                    ,this.orderManager.PairLowestStopLoss(symbol,OP_SELL)
                                    ,this.orderManager.PairHighestTakeProfit(symbol,OP_SELL)
                                    ,false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void BasketSignalScanner::UpdateExits(string symbol)
  {
   this.UpdateBuyExits(symbol);
   this.UpdateSellExits(symbol);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void BasketSignalScanner::UpdateExits(SignalResult *r,bool pinExits)
  {
   bool fixBuy=true;
   bool fixSell=true;
   if(r==NULL)
     {
      return;
     }

   if(r.isSet)
     {
      fixBuy=r.orderType!=OP_BUY;
      fixSell=r.orderType!=OP_SELL;
      this.orderManager.NormalizeExits(
                                       r.symbol,r.orderType,r.stopLoss,
                                       r.takeProfit,pinExits);
      if(fixBuy)
        {
         this.UpdateBuyExits(r.symbol);
        }
      if(fixSell)
        {
         this.UpdateSellExits(r.symbol);
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void BasketSignalScanner::FilterRisk(SignalResult &r)
  {
   if(r.isSet)
     {
      double positionCt=OrderManager::PairOpenPositionCount(r.orderType,r.symbol);
      if(positionCt<1)
        {
         if(r.isSet && r.stopLoss>0 && r.takeProfit>0)
           {
            double tpWidth,slWidth;
            tpWidth=MathAbs(r.takeProfit-r.price);
            slWidth=MathAbs(r.price-r.stopLoss);
            if(tpWidth<(slWidth*this.filterRiskReward))
              {
               r.Reset();
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void BasketSignalScanner::PerSymbolAction(string symbol)
  {
   this.signalSet.Analyze(symbol,this.closePositionsOnOppositeSignal);

   bool noSignal=false;
   if(this.signalSet.Signal==NULL)
     {
      noSignal=true;
     }
   else if(!this.signalSet.Signal.isSet)
     {
      noSignal=true;
     }

   if(noSignal)
     {
      this.UpdateExits(symbol);
      return;
     }

   this.FilterRisk(this.signalSet.Signal);
   if(!this.signalSet.Signal.isSet)
     {
      this.UpdateExits(symbol);
      return;
     }

   SignalResult *r=this.signalSet.Signal;

   if(this.CanSendMarketOrder(r))
     {
      this.orderManager.SendOrder(r,this.lotSize);
      // set all the stoploss and takeprofit to the levels of the new order.
      this.UpdateExits(r,this.disableExitsBacksliding);
     }
   else
     {
      // could not send the order because there were opposite positions and hedging is disabled
      if(this.MustCloseOppositePositions(r))
        {
         // closing orders on opposite signal is enabled
         // close the open orders and begin trading in the opposite direction.
         this.orderManager.CloseOrders(r.symbol,TimeCurrent());
         this.orderManager.SendOrder(r,this.lotSize);
         // set all the stoploss and takeprofit to the levels of the new order.
         this.UpdateExits(r,this.disableExitsBacksliding);
        }
     }

// set all the stoploss and takeprofit to the levels of the signal.
   this.UpdateExits(r,this.disableExitsBacksliding);
  }
//+------------------------------------------------------------------+
