#property strict

//==================== PROGRAM INFO ====================
string   MYCALLSIGN           = "OVERLORD";
string   StatusLabel          = StringConcatenate(MYCALLSIGN, "_STATUS");
string   SpeedLabel           = StringConcatenate(MYCALLSIGN, "_SPEED");
string   TradesLabel          = StringConcatenate(MYCALLSIGN, "_TRADES");
extern   ulong                LoopThreshold  = 100;
extern   int                  RefreshTime    = 0;
extern   double               EntryThreshold = 1.0;
#define  NoOfPlatforms        5
#define  NoOfPairs            23

//TICK CHARTS
#define  NoOfTickChartLines   50
string   TickChartLineNames[NoOfTickChartLines];
datetime BarTimes[NoOfTickChartLines];
double   TickData[NoOfTickChartLines];
double   PreviousPrice, Price;
double   NormalisedData[NoOfTickChartLines];
double   NormalisedMin, NormalisedMax; 

//PAIRS
#define  AUDCAD               0
#define  AUDCHF               1
#define  AUDJPY               2
#define  AUDNZD               3
#define  AUDUSD               4
#define  CADCHF               5
#define  CADJPY               6
#define  CHFJPY               7
#define  EURAUD               8
#define  EURCAD               9
#define  EURCHF               10
#define  EURGBP               11
#define  EURJPY               12
#define  EURNZD               13
#define  EURUSD               14
#define  GBPCHF               15
#define  GBPJPY               16
#define  GBPUSD               17
#define  NZDJPY               18
#define  NZDUSD               19
#define  USDCAD               20
#define  USDCHF               21
#define  USDJPY               22

//==================== PIPES ====================
//PRICE & FILL DATA
#define  PricePipeDataPoints  8 //<<
#define  BID                  0
#define  ASK                  1
#define  TRADEMODE            2
#define  EXEMODE              3
#define  FILLPRICE            4
#define  FILLTIME             5
#define  FILLDIRECTION        6
#define  VOLUME               7
double   PricePipeData[NoOfPairs, PricePipeDataPoints];
double   Prices[NoOfPlatforms, NoOfPairs, PricePipeDataPoints];   //WHERE TO STORE THE ABOVE
string   PRICEFILE[NoOfPlatforms];
int      PRICEPIPE[NoOfPlatforms];

//INSTRUCTIONS
int      InstructionsPipeData[2];                                 //DIRECTION,PAIR
string   INSTRUCTIONSFILE[NoOfPlatforms];
int      INSTRUCTIONSPIPE[NoOfPlatforms];

//LOGS
int      LOGFILE              = 0;

//==================== LOOPING ====================
datetime ProgramStartTime     = 0;
ulong    LoopIncrements       = LoopThreshold;
ulong    LoopIterations       = 0;
ulong    LoopStartTime        = 0;
ulong    AvgLoopTime          = 100000;
ulong    LoopTimeTaken        = 100000;
ulong    Microsecond          = 100000;
ulong    CyclesPerSecond      = 0;
int      i, j, k              = 0;
double   x, y, z              = 0;
int      iPAIR, iPLATFORM     = 0;
int      Min, Max             = 0;
string   str                  = "";
string   str2                 = "";

//==================== TRADING ====================
//TRADE REQUIREMENTS
double   Arb                  = 0;
double   TradeModeRequired    = 4.0;   //FULL
double   ExeModeRequired      = 2.0;   //MARKET
bool     ConditionsMet        = false;

bool     InATrade             = true;
int      TradePair            = 0;
int      BuySide              = 0;
int      SellSide             = 0;

double   BuyPrice_Target      = 0;
double   SellPrice_Target     = 0;
double   BuyPrice_Actual      = 0;
double   SellPrice_Actual     = 0;
double   BuyPrice_Exit        = 0;
double   SellPrice_Exit       = 0;

//STATS
int      TradesTaken          = 0;

//==================== PRICING ====================
//PAIRS
string   PairNames[NoOfPairs];
int      PairDigits[NoOfPairs];
int      PairMultipliers[NoOfPairs];

//PRICES
double   Bids[NoOfPlatforms];
double   Asks[NoOfPlatforms];
double   CombinedVolume[NoOfPairs];
double   SyntheticSpread      = 0;

//TRIANGULATION
double   EUBids[NoOfPlatforms];
double   EUAsks[NoOfPlatforms];

double   EJBids[NoOfPlatforms];
double   EJAsks[NoOfPlatforms];

double   UJBids[NoOfPlatforms];
double   UJAsks[NoOfPlatforms];

//==================== LABELS ====================
string   PlatformLabels[NoOfPlatforms];
string   PairLabels[NoOfPairs];
string   PriceLabels[NoOfPlatforms, NoOfPairs];
string   SyntheticSpreadLabels[NoOfPairs];
string   VolumeLabels[NoOfPairs];

//VISUAL SETTINGS
string   Font                 = "Verdana";
int      FontSize             = 0;
int      StatusFontSize       = 12;
int      TitleFontSize        = 14;
int      PairFontSize         = 12;
int      LabelFontSize        = 10;

int      LeftPosition         = 100;
int      TopPosition          = 130;
int      HorizontalSpacing    = 3;
int      VerticalSpacing      = 20;

color    TitleColours         = clrOrange;
color    PairNameColours      = clrDodgerBlue;
color    PriceColours         = clrDimGray;
color    SpreadColours        = clrLightGoldenrod;
color    VolumeColours        = clrLightGoldenrod;

//==================== INIT / DEINIT ====================
int OnInit()
{
   ConfigureChart();
   DeleteObjects();
   
   MathSrand(GetTickCount());
   
   //SendMail("OVERLORD INITIALISED", "Hi Pete,\n\nThis is just to let you know that the Arbitrage Program has begun trading.");
   
   bool  timerOk = EventSetMillisecondTimer(100);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   for (iPLATFORM= 0; iPLATFORM <= (NoOfPlatforms - 1); iPLATFORM++)
   {
      FileClose(PRICEPIPE[iPLATFORM]);
      FileClose(INSTRUCTIONSPIPE[iPLATFORM]);
   }
   
   FileClose(LOGFILE);
   DeleteObjects();
   
   GlobalVariablesDeleteAll();
}

//================================================================================ PROGRAM START ================================================================================
void OnTimer()
{
   EventKillTimer();
   
   CreateLabel(StatusLabel, "", StatusFontSize, CORNER_LEFT_UPPER, LeftPosition, 20, clrYellow);
   UpdateLabel(StatusLabel, StringConcatenate("PROGRAM STARTED, ", NoOfPlatforms, " PLATFORMS x ", NoOfPairs, " PAIRS"), RefreshTime);
   
   CreateLabel(SpeedLabel, "", StatusFontSize, CORNER_LEFT_UPPER, LeftPosition, 45, clrOrange);
   
   CreateLabel(TradesLabel, "", StatusFontSize, CORNER_LEFT_UPPER, LeftPosition, 70, clrAqua);
   
   //CreateLabel("TRIANGULATION", "TRIANGULATION", StatusFontSize, CORNER_LEFT_UPPER, LeftPosition, 40, clrOrange);
   
   UpdateLabel(StatusLabel, "CREATING LOG FILE", RefreshTime);
      CreateLogFile();
   UpdateLabel(StatusLabel, "CREATING LOG FILE -SUCCESS", RefreshTime);
   
   UpdateLabel(StatusLabel, "CONFIGURING DATA", RefreshTime);
      ConfigureData();
   UpdateLabel(StatusLabel, "CONFIGURING DATA -SUCCESS", RefreshTime);
   
   UpdateLabel(StatusLabel, "CREATING PRICE MATRIX", RefreshTime);
      CreatePriceMatrix();
   UpdateLabel(StatusLabel, "CREATING PRICE MATRIX -SUCCESS", RefreshTime);
   
   /*
   UpdateLabel(StatusLabel, "CREATING TICK CHARTS", RefreshTime);
      CreateTickCharts();
   UpdateLabel(StatusLabel, "CREATING TICK CHARTS -SUCCESS", RefreshTime);
   */
   
   OpenPipes();
   
//================================================================================ BEGIN LOOPING ================================================================================
   ProgramStartTime     = TimeLocal();
   
   while (!IsStopped()) {
   
      LoopIterations++;
      
      //==================== GET DATA FROM PIPE ====================
      for (iPLATFORM = 0; iPLATFORM <= (NoOfPlatforms - 1); iPLATFORM++) {
         //UpdatePricePipe(iPLATFORM);
         
         FileSeek(PRICEPIPE[iPLATFORM], 0, SEEK_SET);
         FileReadArray(PRICEPIPE[iPLATFORM], PricePipeData, 0, WHOLE_ARRAY);
         
         for (iPAIR = 0; iPAIR <= (NoOfPairs - 1); iPAIR++) {
            Prices[iPLATFORM,iPAIR,BID]            = PricePipeData[iPAIR,0];
            Prices[iPLATFORM,iPAIR,ASK]            = PricePipeData[iPAIR,1];
            
            Prices[iPLATFORM,iPAIR,TRADEMODE]      = PricePipeData[iPAIR,2];
            Prices[iPLATFORM,iPAIR,EXEMODE]        = PricePipeData[iPAIR,3];
            
            Prices[iPLATFORM,iPAIR,FILLPRICE]      = PricePipeData[iPAIR,4];
            Prices[iPLATFORM,iPAIR,FILLTIME]       = PricePipeData[iPAIR,5];
            Prices[iPLATFORM,iPAIR,FILLDIRECTION]  = PricePipeData[iPAIR,6];
            
            Prices[iPLATFORM,iPAIR,VOLUME]         = PricePipeData[iPAIR,7];
         }
      }
      
      //==================== 2 LEG ARBITRAGE ====================
      for (iPAIR = 0; iPAIR <= (NoOfPairs - 1); iPAIR++) {
      
         CombinedVolume[iPAIR] = 0;
         
         for (iPLATFORM = 0; iPLATFORM <= (NoOfPlatforms - 1); iPLATFORM++) {
            Bids[iPLATFORM]  = Prices[iPLATFORM,iPAIR,BID];
            Asks[iPLATFORM]  = Prices[iPLATFORM,iPAIR,ASK];
            
            CombinedVolume[iPAIR] += Prices[iPLATFORM,iPAIR,VOLUME];
         }
         
         //TICK CHARTS
         PreviousPrice = Price;
         Price         = ((Prices[0,0,BID] + Prices[0,0,ASK]) / 2);
         
         if ((Price > PreviousPrice) || (Price < PreviousPrice)) {
         
            //PUSH ARRAY DATA BACK A SLOT
            for (i = (NoOfTickChartLines - 1); i >= 0; i--) {
               if (i == 0) {
                  TickData[i] = Price;
               }
               else {
                  TickData[i] = TickData[i-1];
               }
            }
            
            //NORMALISE
            for (i = (NoOfTickChartLines - 1); i >= 0; i--) {
               if (i == 0) {
                  NormalisedMin = TickData[ (ArrayMinimum(TickData, WHOLE_ARRAY, 0)) ];
                  NormalisedMax = TickData[ (ArrayMaximum(TickData, WHOLE_ARRAY, 0)) ];
                  NormalisedData[i] = ((TickData[0] - NormalisedMin) / (NormalisedMax - NormalisedMin));
               }
               else {
                  NormalisedData[i] = NormalisedData[i-1];
               }
            }
         }
         
         //ARBS
         BuySide           = ArrayMinimum(Asks,WHOLE_ARRAY,0);
         SellSide          = ArrayMaximum(Bids,WHOLE_ARRAY,0);
         
         BuyPrice_Target   = Asks[BuySide];
         SellPrice_Target  = Bids[SellSide];
         
         TradePair         = iPAIR;
         Arb               = ((SellPrice_Target - BuyPrice_Target) * PairMultipliers[TradePair]);
         
         ObjectSetString(0, SyntheticSpreadLabels[TradePair], OBJPROP_TEXT, DoubleToStr(Arb, 1));

         if (  (Arb >= EntryThreshold)  ) {
            
            ConditionsMet  =  (! (BuySide == SellSide))
                              && (Prices[BuySide,TradePair,TRADEMODE] == TradeModeRequired)  &&  (Prices[SellSide,TradePair,TRADEMODE] == TradeModeRequired)
                              /*&& (Prices[BuySide,TradePair,EXEMODE] == ExeModeRequired)  &&  (Prices[SellSide,TradePair,EXEMODE] == ExeModeRequired)*/  ;
            
            if (ConditionsMet) {
               
               TradesTaken++;
               
               ObjectSet(PriceLabels[BuySide,TradePair], OBJPROP_COLOR, clrGreenYellow);
               ObjectSet(PriceLabels[SellSide,TradePair], OBJPROP_COLOR, clrRed);
               
               ObjectSetString(0, TradesLabel, OBJPROP_TEXT, StringConcatenate(
                                                                              "LAST TRADE | ",
                                                                              PairNames[TradePair],
                                                                              " | (", BuySide, ") ",
                                                                              DoubleToStr(BuyPrice_Target, PairDigits[TradePair]),
                                                                              " [", DoubleToStr(Arb, 1), "] ",
                                                                              DoubleToStr(SellPrice_Target, PairDigits[TradePair]),
                                                                              " (", SellSide, ") | ",
                                                                              TradesTaken));
                                                                              
               /*
               InstructTradersToEnter();
               GetTradePrices();
               
               while (InATrade == true) {
                  UpdatePricePipe(BuySide);
                  UpdatePricePipe(SellSide);
                  
                  //CALCULATE TRADE GAIN
                  double Leg1PL     = (SellPrice_Actual - Prices[SellSide,TradePair,ASK]);
                  double Leg2PL     = (Prices[BuySide,TradePair,BID] - BuyPrice_Actual);
                  double LatentGain = (Leg1PL + Leg2PL);
                  
                  if (LatentGain >= 0) { InstructTradersToExit(); } //<----- NEEDS PRECISION
                  
                  if (  (Prices[BuySide,TradePair,FILLPRICE] == 0)  &&  (Prices[SellSide,TradePair,FILLPRICE] == 0)  ) {
                     InATrade = false;
                  }
               }
               
               LogTheTrade();
               */
               
               
               break;
            }
         }
      }
            
      //==================== 3 LEG ARBITRAGE ====================
      /*
      for (iPLATFORM = 0; iPLATFORM <= (NoOfPlatforms - 1); iPLATFORM++) {
      
         EJBids[iPLATFORM]  = Prices[iPLATFORM,EURJPY,BID];
         EJAsks[iPLATFORM]  = Prices[iPLATFORM,EURJPY,ASK];
         
         EUBids[iPLATFORM]  = Prices[iPLATFORM,EURUSD,BID];
         EUAsks[iPLATFORM]  = Prices[iPLATFORM,EURUSD,ASK];
         
         UJBids[iPLATFORM]  = Prices[iPLATFORM,USDJPY,BID];
         UJAsks[iPLATFORM]  = Prices[iPLATFORM,USDJPY,ASK];
      }
      
      //LONG SIDE
      double Leg1_Target = EUAsks[ (ArrayMinimum(EUAsks,WHOLE_ARRAY,0)) ]; //LONG EURUSD
      double Leg2_Target = EJBids[ (ArrayMaximum(EJBids,WHOLE_ARRAY,0)) ]; //SHORT EURJPY
      double Leg3_Target = UJAsks[ (ArrayMinimum(UJAsks,WHOLE_ARRAY,0)) ]; //LONG USDJPY
      
      //SHORT SIDE
      double Leg4_Target = EUBids[ (ArrayMaximum(EUBids,WHOLE_ARRAY,0)) ]; //SHORT EURUSD
      double Leg5_Target = EJAsks[ (ArrayMinimum(EJAsks,WHOLE_ARRAY,0)) ]; //LONG EURJPY
      double Leg6_Target = UJBids[ (ArrayMaximum(UJBids,WHOLE_ARRAY,0)) ]; //SHORT USDJPY
         
      x = (Leg1_Target + Leg2_Target + Leg3_Target);
      y = (Leg4_Target + Leg5_Target + Leg6_Target);
      
      ObjectSetString(0, "TRIANGULATION", OBJPROP_TEXT, StringConcatenate(
                                                                           DoubleToStr(x, 5), " x ", DoubleToStr(y, 5),
                                                                           " [", DoubleToStr((x - y), 5), "]"));
      */
      
      //==================== UPDATE SCREEN ====================
      if (LoopIterations >= LoopThreshold) {
         
         for (iPAIR = 0; iPAIR <= (NoOfPairs - 1); iPAIR++) {
            
            for (iPLATFORM = 0; iPLATFORM <= (NoOfPlatforms - 1); iPLATFORM++) {
               
               //PRICES
               ObjectSet(PriceLabels[iPLATFORM,iPAIR], OBJPROP_COLOR, PriceColours);
               ObjectSetString(0, PriceLabels[iPLATFORM,iPAIR], OBJPROP_TEXT, StringConcatenate(
                                                                                 DoubleToStr(Prices[iPLATFORM,iPAIR,BID], PairDigits[iPAIR]),
                                                                                 " x ",
                                                                                 DoubleToStr(Prices[iPLATFORM,iPAIR,ASK], PairDigits[iPAIR])
                                                                                 ));
            }
            
            //VOLUME
            ObjectSetString(0, VolumeLabels[iPAIR], OBJPROP_TEXT, DoubleToStr(CombinedVolume[iPAIR], 0));
         }
         
         //STATUS
         ObjectSetString(0, StatusLabel, OBJPROP_TEXT, StringConcatenate(
                                                                  MYCALLSIGN, " | ",
                                                                  "RUNTIME ", TimeToStr((TimeLocal() - ProgramStartTime), TIME_SECONDS),
                                                                  " | THRESH ", LoopIncrements, " / ", DoubleToStr(EntryThreshold, 1)
                                                                  ));
         
         //SPEED
         ObjectSetString(0, SpeedLabel, OBJPROP_TEXT, StringConcatenate(
                                                                  LoopIterations, " CYCLES | ",
                                                                  AvgLoopTime, " µs AVG | ",
                                                                  DoubleToStr(  MathRound((CyclesPerSecond / 100) * 100)  ,0),
                                                                  " / SECOND"));
         
         /*
         for (i = 0; i <= (NoOfTickChartLines - 2); i++) {
            ObjectMove(TickChartLineNames[i], 0, BarTimes[i], NormalisedData[i]);
            ObjectMove(TickChartLineNames[i], 1, BarTimes[i + 1], NormalisedData[i+1]);
         }
         */
         
         WindowRedraw();
         
         //TIMINGS
         AvgLoopTime       = (LoopTimeTaken / LoopIncrements);
         CyclesPerSecond   = (1000000 / AvgLoopTime);
         LoopThreshold = (LoopIterations + LoopIncrements);
         Microsecond   = GetMicrosecondCount();
         LoopTimeTaken = (Microsecond - LoopStartTime);
         LoopStartTime = Microsecond;
      }
   }
}
//================================================================================ END LOOPING ================================================================================


int CreateTickCharts() {
   
   #define  TickChartLines       (NoOfTickChartLines - 1)
   
   for (i = 0; i <= (NoOfTickChartLines - 1); i++) {
      BarTimes[i] = iTime(Symbol(), PERIOD_CURRENT, i);
   }
   
   for (i = 0; i <= (NoOfTickChartLines - 2); i++) {
      datetime xStartPos   = BarTimes[i];
      datetime xEndPos     = BarTimes[i+1];
      
      double yStartPos   = 1.0;
      double yEndPos     = 1.0;
      
      TickChartLineNames[i] = StringConcatenate("TICKCHART_", i);
   
      if (!ObjectCreate(TickChartLineNames[i], OBJ_TREND, 0, xStartPos, yStartPos, xEndPos, yEndPos)) {
         Print("ERROR CREATING TICK LINE, ", GetLastError()); ExpertRemove();
      }
      else if (!ObjectSet(TickChartLineNames[i], OBJPROP_RAY, false)) {
         Print("ERROR SETTING TICK LINE RAY, ", GetLastError()); ExpertRemove();
      }
      else if (!ObjectSet(TickChartLineNames[i], OBJPROP_COLOR, clrGreen)) {
         Print("ERROR SETTING TICK LINE COLOUR, ", GetLastError()); ExpertRemove();
      }
   }
   
   return(0);
}


int CreatePriceMatrix() {

   int      xCoords[NoOfPairs + 1]; ArrayInitialize(xCoords, LeftPosition);
   int      yCoords[NoOfPairs + 1]; ArrayInitialize(yCoords, TopPosition);
         
   int      Widths[NoOfPairs + 1];  ArrayInitialize(Widths, 0);
   int      Heights[NoOfPairs + 1]; ArrayInitialize(Heights, 0);
      
   //_____ PAIRS _____
   FontSize = PairFontSize;
   TextSetFont(Font, -FontSize*10);
   
   for (i = 0; i <= (NoOfPairs - 1); i++) {
      if (i < 10) { str2 = "0"; }
      else { str2 = ""; }
      
      str = StringConcatenate("[", str2, i, "] ", PairNames[i]);
      CreateLabel(PairNames[i], str, FontSize, 0, xCoords[0], yCoords[i], PairNameColours);
      TextGetSize(str, Widths[i], Heights[i]);
      
      yCoords[i+1] = yCoords[i] + Heights[i] + HorizontalSpacing;
   }
   
   FontSize = TitleFontSize;
   TextSetFont(Font, -FontSize*10);
   
   CreateLabel("PAIRLABEL", "PAIR", TitleFontSize, 0, xCoords[0], 0, TitleColours);
   TextGetSize("PAIR", Widths[0], Heights[0]);
   ObjectSetInteger(0, "PAIRLABEL", OBJPROP_YDISTANCE, (yCoords[0] - Heights[0] - HorizontalSpacing));
   
   Max = ArrayMaximum(Widths, WHOLE_ARRAY, 0);
   xCoords[0] = xCoords[0] + Widths[Max] + VerticalSpacing;

   //_____ VOLUMES _____
   FontSize = LabelFontSize;
   TextSetFont(Font, -FontSize*10);
      
   for (i = 0; i <= (NoOfPairs - 1); i++) {
      VolumeLabels[i] = StringConcatenate("VOLUME_", PairNames[i]);
      CreateLabel(VolumeLabels[i], "000000", FontSize, 0, xCoords[0], yCoords[i], VolumeColours);
      TextGetSize("000000", Widths[i], Heights[i]);
   }
   
   FontSize = TitleFontSize;
   TextSetFont(Font, -FontSize*10);
   
   CreateLabel("VOLUMELABEL", "VOL", TitleFontSize, 0, xCoords[0], 0, TitleColours);
   TextGetSize("VOL", Widths[0], Heights[0]);
   ObjectSetInteger(0, "VOLUMELABEL", OBJPROP_YDISTANCE, (yCoords[0] - Heights[0] - HorizontalSpacing));
   
   Max = ArrayMaximum(Widths, WHOLE_ARRAY, 0);
   xCoords[0] = xCoords[0] + Widths[Max] + VerticalSpacing;
   
   //_____ SPREADS _____
   FontSize = LabelFontSize;
   TextSetFont(Font, -FontSize*10);
      
   for (i = 0; i <= (NoOfPairs - 1); i++) {
      SyntheticSpreadLabels[i] = StringConcatenate("SYNTHETIC_SPREAD_", PairNames[i]);
      CreateLabel(SyntheticSpreadLabels[i], "0000", FontSize, 0, xCoords[0], yCoords[i], SpreadColours);
      TextGetSize("0000", Widths[i], Heights[i]);
   }
   
   FontSize = TitleFontSize;
   TextSetFont(Font, -FontSize*10);
   
   CreateLabel("SPREADLABEL", "SPR", TitleFontSize, 0, xCoords[0], 0, TitleColours);
   TextGetSize("SPR", Widths[0], Heights[0]);
   ObjectSetInteger(0, "SPREADLABEL", OBJPROP_YDISTANCE, (yCoords[0] - Heights[0] - HorizontalSpacing));
   
   Max = ArrayMaximum(Widths, WHOLE_ARRAY, 0);
   xCoords[0] = xCoords[0] + Widths[Max] + VerticalSpacing;   
   
   for (i = 0; i <= (NoOfPlatforms - 1); i++) {
      
      //_____ PRICES _____
      FontSize = LabelFontSize;
      TextSetFont(Font, -FontSize*10);
         
      for (j = 0; j <= (NoOfPairs - 1); j++) {
         PriceLabels[i,j] = StringConcatenate("HITMAN_", i, "_PRICE_", PairNames[j]);
         CreateLabel(PriceLabels[i,j], "1.00000 x 2.00000", FontSize, 0, xCoords[0], yCoords[j], PriceColours);
         TextGetSize("1.00000 x 2.00000", Widths[j], Heights[j]);
      }
      
      //_____ PLATFORM NAMES _____
      FontSize = TitleFontSize;
      TextSetFont(Font, -FontSize*10);
      
      PlatformLabels[i] = StringConcatenate("HITMAN_", i, "_PLATFORM");
      CreateLabel(PlatformLabels[i], StringConcatenate("HITMAN ", i), FontSize, 0, xCoords[0], yCoords[0], TitleColours);
      TextGetSize(StringConcatenate("HITMAN ", i), Widths[i], Heights[i]);
      ObjectSetInteger(0, PlatformLabels[i], OBJPROP_YDISTANCE, (yCoords[0] - Heights[i] - HorizontalSpacing));
      
      Max = ArrayMaximum(Widths, WHOLE_ARRAY, 0);
      xCoords[0] = xCoords[0] + Widths[Max] + VerticalSpacing;
   }
   
   return(0);
}


int UpdatePricePipe(int Platform) {
   FileSeek(PRICEPIPE[Platform], 0, SEEK_SET);
   FileReadArray(PRICEPIPE[Platform], PricePipeData, 0, WHOLE_ARRAY);
   
   for (iPAIR = 0; iPAIR <= (NoOfPairs - 1); iPAIR++) {
      Prices[Platform,iPAIR,BID]            = PricePipeData[iPAIR,0];
      Prices[Platform,iPAIR,ASK]            = PricePipeData[iPAIR,1];
      
      Prices[Platform,iPAIR,TRADEMODE]      = PricePipeData[iPAIR,2];
      Prices[Platform,iPAIR,EXEMODE]        = PricePipeData[iPAIR,3];
      
      Prices[Platform,iPAIR,FILLPRICE]      = PricePipeData[iPAIR,4];
      Prices[Platform,iPAIR,FILLTIME]       = PricePipeData[iPAIR,5];
      Prices[Platform,iPAIR,FILLDIRECTION]  = PricePipeData[iPAIR,6];
      
      Prices[Platform,iPAIR,VOLUME]         = PricePipeData[iPAIR,7];
   }
        
   return(0);
}


int InstructTradersToEnter() {
   InstructionsPipeData[1] = TradePair;
   
   //BUYER
   InstructionsPipeData[0] = 1.0;
   
   FileSeek       (INSTRUCTIONSPIPE[BuySide], 0, SEEK_SET);
   FileWriteArray (INSTRUCTIONSPIPE[BuySide], InstructionsPipeData, 0, WHOLE_ARRAY);
   FileFlush      (INSTRUCTIONSPIPE[BuySide]);
   
   //SELLER
   InstructionsPipeData[0] = -1.0;

   FileSeek       (INSTRUCTIONSPIPE[SellSide], 0, SEEK_SET);
   FileWriteArray (INSTRUCTIONSPIPE[SellSide], InstructionsPipeData, 0, WHOLE_ARRAY);
   FileFlush      (INSTRUCTIONSPIPE[SellSide]);
   
   return(0);
}


int GetTradePrices() {
   BuyPrice_Actual   = 0;
   SellPrice_Actual  = 0;
   
   //BUYER
   while (  (BuyPrice_Actual == 0)  &&  (!IsStopped())  )
   {
      FileSeek(PRICEPIPE[BuySide], 0, SEEK_SET);
      FileReadArray(PRICEPIPE[BuySide], PricePipeData, 0, WHOLE_ARRAY);
      BuyPrice_Actual  = PricePipeData[TradePair,FILLPRICE];
   }
   
   //SELLER
   while (  (SellPrice_Actual == 0)  &&  (!IsStopped())  )
   {
      FileSeek(PRICEPIPE[SellSide], 0, SEEK_SET);
      FileReadArray(PRICEPIPE[SellSide], PricePipeData, 0, WHOLE_ARRAY);
      SellPrice_Actual  = PricePipeData[TradePair,FILLPRICE];
   }
   
   InATrade    = true;
   
   return(0);
}


int InstructTradersToExit() {
   InstructionsPipeData[0] = 0;
   
   //BUYER
   FileSeek       (INSTRUCTIONSPIPE[BuySide], 0, SEEK_SET);
   FileWriteArray (INSTRUCTIONSPIPE[BuySide], InstructionsPipeData, 0, WHOLE_ARRAY);
   FileFlush      (INSTRUCTIONSPIPE[BuySide]);
   
   //SELLER
   FileSeek       (INSTRUCTIONSPIPE[SellSide], 0, SEEK_SET);
   FileWriteArray (INSTRUCTIONSPIPE[SellSide], InstructionsPipeData, 0, WHOLE_ARRAY);
   FileFlush      (INSTRUCTIONSPIPE[SellSide]);
   
   return(0);
}


int GetExitPrices() {
   FileSeek(PRICEPIPE[BuySide], 0, SEEK_SET);
   FileReadArray(PRICEPIPE[BuySide], PricePipeData, 0, WHOLE_ARRAY);
   SellPrice_Exit = PricePipeData[TradePair,BID];
   
   FileSeek(PRICEPIPE[SellSide], 0, SEEK_SET);
   FileReadArray(PRICEPIPE[SellSide], PricePipeData, 0, WHOLE_ARRAY);
   BuyPrice_Exit = PricePipeData[TradePair,ASK];
   
   return(0);
}


int OpenPipes() {
   //==================== PRICES ====================
   for (iPLATFORM = 0; iPLATFORM <= (NoOfPlatforms - 1); iPLATFORM++)
   {
      UpdateLabel(StatusLabel, StringConcatenate("CONNECTING TO HITMAN ", iPLATFORM), RefreshTime);
      
      PRICEFILE[iPLATFORM] = StringConcatenate("HITMAN_", iPLATFORM, "_PRICES.bin");
      PRICEPIPE[iPLATFORM] = -1;
      
      while (  (PRICEPIPE[iPLATFORM] == -1)  &&  (! IsStopped())  )
      {
         PRICEPIPE[iPLATFORM] = FileOpen(PRICEFILE[iPLATFORM], FILE_READ|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_BIN|FILE_COMMON); //READ ONLY
         FileSeek(PRICEPIPE[iPLATFORM], 0, SEEK_SET);
      }
      
      UpdateLabel(StatusLabel, StringConcatenate("CONNECTING TO HITMAN ", iPLATFORM, " -SUCCESS"), RefreshTime);
   }
   
   //==================== INSTRUCTIONS ====================
   for (iPLATFORM = 0; iPLATFORM <= (NoOfPlatforms - 1); iPLATFORM++)
   {
      UpdateLabel(StatusLabel, StringConcatenate("CREATING INSTRUCTIONS FOR HITMAN ", iPLATFORM), RefreshTime);
      
      INSTRUCTIONSFILE[iPLATFORM] = StringConcatenate("HITMAN_", iPLATFORM, "_INSTRUCTIONS.bin");
      INSTRUCTIONSPIPE[iPLATFORM] = -1;
      
      while (  (INSTRUCTIONSPIPE[iPLATFORM] == -1)  &&  (!IsStopped())  )
      {
         INSTRUCTIONSPIPE[iPLATFORM] = FileOpen(INSTRUCTIONSFILE[iPLATFORM], FILE_WRITE|FILE_SHARE_READ|FILE_BIN|FILE_COMMON);
         FileSeek (INSTRUCTIONSPIPE[iPLATFORM], 0, SEEK_SET);
      }
      
      InstructionsPipeData[0] = 0;
      InstructionsPipeData[1] = 0;   
      FileWriteArray(INSTRUCTIONSPIPE[iPLATFORM], InstructionsPipeData, 0, WHOLE_ARRAY);
      FileFlush(INSTRUCTIONSPIPE[iPLATFORM]);
      
      UpdateLabel(StatusLabel, StringConcatenate("CREATING INSTRUCTIONS FOR HITMAN ", iPLATFORM, " -SUCCESS"), RefreshTime);
   }
   
   return(0);
}


int CreateLogFile() {
   datetime CurrentTime = TimeLocal();
   string   FileName = StringConcatenate("TRADELOG_", TimeHour(CurrentTime), "_", TimeMinute(CurrentTime), ".csv");
   LOGFILE        = FileOpen(FileName, FILE_WRITE|FILE_SHARE_READ|FILE_CSV|FILE_COMMON);
   FileSeek(LOGFILE, 0, SEEK_SET);
   FileWrite(LOGFILE, "TIME,PAIR,BUYSIDE,TARGETBUYPRICE,ACTUALBUYPRICE,ARB,ACTUALSELLPRICE,TARGETSELLPRICE,SELLSIDE,");
   FileFlush(LOGFILE);
   
   return(0);
}


int LogTheTrade() {
   FileWrite(LOGFILE, StringConcatenate(
                                       TimeToStr(TimeLocal(),TIME_SECONDS), ",",
                                       PairNames[TradePair], ",",
                                       BuySide, ",",
                                       DoubleToStr(BuyPrice_Target, PairDigits[TradePair]), ",",
                                       DoubleToStr(BuyPrice_Actual, PairDigits[TradePair]), ",",
                                       DoubleToStr(Arb, 1), ",",
                                       DoubleToStr(SellPrice_Actual, PairDigits[TradePair]), ",",
                                       DoubleToStr(BuyPrice_Target, PairDigits[TradePair]), ",",
                                       SellSide
                                       ));

   FileFlush(LOGFILE);
   
   TradesTaken++;

   return(0);
}
                                       

int CreateLabel(string LabelName, string LabelText, int myFontSize, int LabelCorner, int xDistance, int yDistance, color LabelColour) {
   if(ObjectFind(LabelName) == -1) {
      ObjectCreate(LabelName, OBJ_LABEL, 0, 0, 0);
   }
   
   ObjectSet(LabelName, OBJPROP_CORNER, LabelCorner);
   ObjectSetString(0, LabelName, OBJPROP_FONT, Font);
   ObjectSetInteger(0, LabelName, OBJPROP_FONTSIZE, myFontSize);
   ObjectSetString(0, LabelName, OBJPROP_TEXT, LabelText);
   ObjectSetInteger(0, LabelName, OBJPROP_XDISTANCE, xDistance);
   ObjectSetInteger(0, LabelName, OBJPROP_YDISTANCE, yDistance);
   ObjectSetText(LabelName, LabelText, FontSize, Font, LabelColour);
   
   return(0);
}


int UpdateLabel(string LabelName, string Text, int SleepTime) {
   ObjectSetText(LabelName, Text);
   ChartRedraw();
   
   if (SleepTime > 0) { Sleep(SleepTime); }
   
   return(0);
}


int UpdateLabelNoRedraw(string LabelName, string Text) {
   ObjectSetText(LabelName, Text);
   
   return(0);
}



int DeleteObjects() {
   int obj_total = ObjectsTotal();
   int iObjects = 0;
   
   for(iObjects = obj_total - 1; iObjects >= 0; iObjects--)
   {
      string name = ObjectName(iObjects);
      ObjectDelete(name);
   }
   
   return(0);
}


int ConfigureChart() {
   double ChartScaleTop    = 1.1;
   double ChartScaleBottom = -0.1;

   ChartSetSymbolPeriod(0, "EURJPY", PERIOD_D1);
   ChartSetInteger(0, CHART_SCALEFIX, 0, true);
   ChartSetDouble(0, CHART_FIXED_MAX, ChartScaleTop);
   ChartSetDouble(0, CHART_FIXED_MIN, ChartScaleBottom);
   ChartSetInteger(0, CHART_AUTOSCROLL, 0, true);
   ChartSetInteger(0, CHART_FOREGROUND, 0, false);
   ChartSetInteger(0, CHART_SHOW_BID_LINE, 0, false);
   ChartSetInteger(0, CHART_SHOW_ASK_LINE, 0, false);
   ChartSetInteger(0, CHART_SHOW_GRID, 0, false);
   ChartSetInteger(0, CHART_SHOW_OHLC, 0, false);
   ChartSetInteger(0, CHART_SHOW_PERIOD_SEP, 0, false);
   ChartSetInteger(0, CHART_SHOW_VOLUMES, 0, false);
   ChartSetInteger(0, CHART_SHOW_OBJECT_DESCR, 0, false);
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, 0, clrBlack);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, 0, clrGray);
   ChartSetInteger(0, CHART_COLOR_GRID, 0, clrBlack);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, 0, clrBlack);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, 0, clrBlack);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, 0, clrBlack);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, 0, clrBlack);
   ChartSetInteger(0, CHART_COLOR_CHART_LINE, 0, clrBlack);
   ChartSetInteger(0, CHART_COLOR_VOLUME, 0, clrBlack);
   ChartSetInteger(0, CHART_COLOR_BID, 0, clrBlack);
   ChartSetInteger(0, CHART_COLOR_ASK, 0, clrBlack);
   
   return(0);
}


int ConfigureData() {
   PairNames[0]   = "AUDCAD";
   PairNames[1]   = "AUDCHF";
   PairNames[2]   = "AUDJPY";
   PairNames[3]   = "AUDNZD";
   PairNames[4]   = "AUDUSD";
   PairNames[5]   = "CADCHF";
   PairNames[6]   = "CADJPY";
   PairNames[7]   = "CHFJPY";
   PairNames[8]   = "EURAUD";
   PairNames[9]   = "EURCAD";
   PairNames[10]  = "EURCHF";
   PairNames[11]  = "EURGBP";
   PairNames[12]  = "EURJPY";
   PairNames[13]  = "EURNZD";
   PairNames[14]  = "EURUSD";
   PairNames[15]  = "GBPCHF";
   PairNames[16]  = "GBPJPY";
   PairNames[17]  = "GBPUSD";   
   PairNames[18]  = "NZDJPY";
   PairNames[19]  = "NZDUSD";
   PairNames[20]  = "USDCAD";
   PairNames[21]  = "USDCHF";
   PairNames[22]  = "USDJPY";
   
   for (iPAIR = 0; iPAIR <= (NoOfPairs - 1); iPAIR++) {
      if (iPAIR == 0 || iPAIR == 1 || iPAIR == 3 || iPAIR == 4 || iPAIR == 5 || iPAIR == 8 || iPAIR == 9 || iPAIR == 10 || iPAIR == 11 || iPAIR == 13 || iPAIR == 14 
      || iPAIR == 15 || iPAIR == 17 || iPAIR == 19 || iPAIR == 20 || iPAIR == 21) {
         PairDigits[iPAIR] = 5;
         PairMultipliers[iPAIR] = 10000; 
      }
      else {
         PairDigits[iPAIR] = 3;
         PairMultipliers[iPAIR] = 100;
      }
   }
   
   return(0);
}

