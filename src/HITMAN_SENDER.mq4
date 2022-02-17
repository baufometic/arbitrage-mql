#property strict

//==================== PROGRAM INFO ====================
string   MYINSTANCE           = StringSubstr(TerminalPath(), (StringFind(TerminalPath(), "_", 0) + 1), 1);
string   MYCALLSIGN           = StringConcatenate("HITMAN_", MYINSTANCE);
string   MYRANK               = "SENDER";
string   MYBROKER             = TerminalCompany();
bool     uMYBROKER            = StringToUpper(MYBROKER);
extern   ulong                LoopThreshold     = 10000;
extern   int                  RefreshTime       = 20;
extern   string               PairExtension     = "";
#define  NoOfPairs            23

//==================== PIPES ====================
//PRICE...FILL...TRADING
#define  PricePipeDataPoints  8
#define  BID                  0
#define  ASK                  1
#define  TRADEMODE            2
#define  EXEMODE              3
#define  FILLPRICE            4
#define  FILLTIME             5
#define  FILLDIRECTION        6
#define  VOLUME               7
double   PricePipeData[NoOfPairs, PricePipeDataPoints];
string   PRICEFILE            = StringConcatenate(MYCALLSIGN, "_PRICES.bin");
int      PRICEPIPE            = -1;

//==================== ARRAYS ====================
string   PairNames[NoOfPairs];
int      PairDigits[NoOfPairs];
int      PairMultipliers[NoOfPairs];

//==================== LOOPING ====================
datetime ProgramStartTime     = 0;
ulong    LoopIncrements       = LoopThreshold;
ulong    LoopIterations       = 0;
ulong    LoopStartTime        = 0;
ulong    LoopTimeTaken        = 0;
ulong    Microsecond          = 0;
int      i, j, iPAIR          = 0;
string   str                  = "";

//==================== LABELS ====================
string   StatusLabel          = "StatusLabel";
string   DirectoryLabel       = "DirectoryLabel";
string   LotInfoLabel         = "LotInfoLabel";
string   ExecutionInfoLabel   = "ExecutionInfoLabel";

//==================== INIT / DEINIT ====================
int OnInit()
{
   ConfigureChart();
   DeleteObjects();
   
   bool  timerOk = EventSetMillisecondTimer(1000);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   FileClose(PRICEPIPE);
   DeleteObjects();
}

//================================================================================ PROGRAM START ================================================================================
void OnTimer()
{
   EventKillTimer();
   
   //==================== CREATE LABELS ====================
   CreateLabel(StatusLabel, "", 12, 2, 10, 100, clrYellow);
   CreateLabel(DirectoryLabel, "", 12, 2, 10, 80, clrYellow);
   CreateLabel(LotInfoLabel, "", 12, 2, 10, 60, clrLightBlue);
   CreateLabel(ExecutionInfoLabel, "", 12, 2, 10, 40, clrLightBlue);
   
   UpdateLabel(StatusLabel, "PROGRAM STARTED", RefreshTime);
   
   i = StringFind(TerminalPath(), "\\", 0) + 1;
   j = StringFind(TerminalPath(), "\\", i) + 1;
   str = StringConcatenate(
                           MYCALLSIGN, " ", MYRANK, " | ",
                           StringSubstr(TerminalPath(), j, (StringLen(TerminalPath()) - j)), " | ",
                           MYBROKER
                           );
   UpdateLabel(DirectoryLabel, str, RefreshTime);
   str = "";
   
   UpdateLabel(LotInfoLabel, StringConcatenate("Min ", MarketInfo(Symbol(),MODE_MINLOT),
                                               " | Max ", MarketInfo(Symbol(),MODE_MAXLOT),
                                               " | Step ", MarketInfo(Symbol(),MODE_LOTSTEP),
                                               " | MrgReq ", MarketInfo(Symbol(),MODE_MARGININIT),
                                               " | Frz ", MarketInfo(Symbol(),MODE_FREEZELEVEL)
                                               ), RefreshTime);
   UpdateLabel(ExecutionInfoLabel, GetExecutionInfo(), RefreshTime);
   
   //==================== PROVIDERS / PAIR / DIGIT INFORMATION ====================
   UpdateLabel(StatusLabel, "CONFIGURING DATA", RefreshTime);
   ConfigureData();
   UpdateLabel(StatusLabel, "CONFIGURING DATA -SUCCESS", RefreshTime);
   
   //=================== PIPES ====================
   OpenPipes();
   
   //================================================================================ BEGIN LOOPING ================================================================================   
   ProgramStartTime = TimeLocal();
   
   while (!IsStopped())
   {
      LoopIterations++;
      
      //==================== SEND PRICE / TRADE INFO ====================
      RefreshRates();
      for (iPAIR = 0; iPAIR <= (NoOfPairs - 1); iPAIR++)
      {
         //===== PRICE DATA =====
         PricePipeData[iPAIR,BID]      = SymbolInfoDouble(PairNames[iPAIR], SYMBOL_BID);
         PricePipeData[iPAIR,ASK]      = SymbolInfoDouble(PairNames[iPAIR], SYMBOL_ASK);
         
         PricePipeData[iPAIR,VOLUME]   = (1.0 * iVolume(PairNames[iPAIR], PERIOD_D1, 0));
         
         //===== TRADE MODES =====
         i = (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);
         switch(i) {
            case SYMBOL_TRADE_MODE_DISABLED:       PricePipeData[iPAIR,TRADEMODE] = 0.0; break;   //DISABLED
            case SYMBOL_TRADE_MODE_LONGONLY:       PricePipeData[iPAIR,TRADEMODE] = 1.0; break;   //LONG ONLY
            case SYMBOL_TRADE_MODE_SHORTONLY:      PricePipeData[iPAIR,TRADEMODE] = 2.0; break;   //SHORT ONLY
            case SYMBOL_TRADE_MODE_CLOSEONLY:      PricePipeData[iPAIR,TRADEMODE] = 3.0; break;   //CLOSE ONLY
            case SYMBOL_TRADE_MODE_FULL:           PricePipeData[iPAIR,TRADEMODE] = 4.0; break;   //FULL
         }
         
         i = (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_EXEMODE);
         switch(i) {
            case SYMBOL_TRADE_EXECUTION_REQUEST:   PricePipeData[iPAIR,EXEMODE] = 0.0; break;   //REQUEST
            case SYMBOL_TRADE_EXECUTION_INSTANT:   PricePipeData[iPAIR,EXEMODE] = 1.0; break;   //INSTANT
            case SYMBOL_TRADE_EXECUTION_MARKET:    PricePipeData[iPAIR,EXEMODE] = 2.0; break;   //MARKET
            case SYMBOL_TRADE_EXECUTION_EXCHANGE:  PricePipeData[iPAIR,EXEMODE] = 3.0; break;   //EXCHANGE
         }
         
         //===== POSITION INFORMATION =====
         int TotalOrders = OrdersTotal();
         
         PricePipeData[iPAIR,FILLPRICE]      = 0;
         PricePipeData[iPAIR,FILLTIME]       = 0;
         PricePipeData[iPAIR,FILLDIRECTION]  = 0;
         
         if (TotalOrders > 0)
         {
            for (i = (TotalOrders - 1); i >= 0 ; i--)
            {
               if ( ! OrderSelect(i, SELECT_BY_POS, MODE_TRADES) ) continue;  // <-- if the OrderSelect fails, advance to next loop iteration
               
               if (OrderSymbol() == PairNames[iPAIR])
               {
                  PricePipeData[iPAIR,FILLPRICE] = OrderOpenPrice();
                  PricePipeData[iPAIR,FILLTIME] = (1.0 * OrderOpenTime());
                  
                  //******** THESE ONLY WORK FOR EXECUTED ORDERS!!! *********
                  //ADJUST ACCORDINGLY FOR LIMIT ORDERS 'OP_BUYLIMIT'
                  if (OrderType() == OP_BUY) {
                     PricePipeData[iPAIR,FILLDIRECTION] = 1;
                  }
                  else if (OrderType() == OP_SELL) {
                     PricePipeData[iPAIR,FILLDIRECTION] = -1;
                  }
               }
            }
         }
      }
      
      FileSeek(PRICEPIPE, 0, SEEK_SET);
      FileWriteArray(PRICEPIPE, PricePipeData, 0, WHOLE_ARRAY); FileFlush(PRICEPIPE);

      //==================== UPDATE SCREEN ====================
      if (LoopIterations >= LoopThreshold)
      {
         UpdateLabel(StatusLabel, StringConcatenate(
                                       TimeToStr((TimeLocal() - ProgramStartTime), TIME_SECONDS), " | ",
                                       LoopIterations, " | ",
                                       (LoopTimeTaken / LoopIncrements), " µs"
                                       ), 0);
         
         LoopThreshold = (LoopIterations + LoopIncrements);
         Microsecond   = GetMicrosecondCount();
         LoopTimeTaken = (Microsecond - LoopStartTime);
         LoopStartTime  = Microsecond;
      }
   }
}
//================================================================================ END LOOPING ================================================================================


int OpenPipes()
{
   //==================== PRICES ====================
   UpdateLabel(StatusLabel, "CREATING PRICE PIPE", RefreshTime);
   while (  (PRICEPIPE == -1) && (!IsStopped())  )
   {
      PRICEPIPE = FileOpen(PRICEFILE, FILE_WRITE|FILE_SHARE_READ|FILE_BIN|FILE_COMMON);
      FileSeek(PRICEPIPE, 0, SEEK_SET);
   }
   UpdateLabel(StatusLabel, "CREATING PRICE PIPE -SUCCESS", RefreshTime);
   
   return(0);
}

int CreateLabel(string LabelName, string LabelText, int FontSize, int LabelCorner, int xDistance, int yDistance, color LabelColour)
{
   if(ObjectFind(LabelName) == -1) { ObjectCreate(LabelName, OBJ_LABEL, 0, 0, 0); }
   
   ObjectSet(LabelName, OBJPROP_CORNER, LabelCorner);
   ObjectSet(LabelName, OBJPROP_XDISTANCE, xDistance);
   ObjectSet(LabelName, OBJPROP_YDISTANCE, yDistance);
   ObjectSetText(LabelName, LabelText, FontSize, "Verdana", LabelColour);
   ChartRedraw();
   
   return(0);
}

int UpdateLabel(string LabelName, string Text, int SleepTime)
{
   ObjectSetText(LabelName, Text);
   ChartRedraw();
   
   if (SleepTime > 0) { Sleep(SleepTime); }
   
   return(0);
}

int DeleteObjects()
{
   int obj_total = ObjectsTotal();
   int iObjects = 0;
   
   for(iObjects = obj_total - 1; iObjects >= 0; iObjects--)
   {
      string name = ObjectName(iObjects);
      ObjectDelete(name);
   }
   
   return(0);
}

int ConfigureChart()
{
   ChartSetSymbolPeriod(0, Symbol(), PERIOD_D1);
   ChartSetInteger(0, CHART_SCALEFIX, 0, true);
   ChartSetDouble(0, CHART_FIXED_MAX, 105);
   ChartSetDouble(0, CHART_FIXED_MIN, -5);
   ChartSetInteger(0, CHART_AUTOSCROLL, 0, true);
   ChartSetInteger(0, CHART_FOREGROUND, 0, false);
   ChartSetInteger(0, CHART_SHOW_TRADE_LEVELS, 0, false);
   ChartSetInteger(0, CHART_SHOW_BID_LINE, 0, false);
   ChartSetInteger(0, CHART_SHOW_ASK_LINE, 0, false);
   ChartSetInteger(0, CHART_SHOW_LAST_LINE, 0, false);
   ChartSetInteger(0, CHART_SHOW_GRID, 0, false);
   ChartSetInteger(0, CHART_SHOW_OHLC, 0, false);
   ChartSetInteger(0, CHART_SHOW_PERIOD_SEP, 0, false);
   ChartSetInteger(0, CHART_SHOW_VOLUMES, 0, false);
   ChartSetInteger(0, CHART_SHOW_OBJECT_DESCR, 0, false);
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, 0, clrBlack);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, 0, clrBlack);
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

int ConfigureData()
{
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
   
   for (iPAIR = 0; iPAIR <= (NoOfPairs - 1); iPAIR++)
   {
      PairNames[iPAIR] = StringConcatenate(PairNames[iPAIR], PairExtension);
      
      if (iPAIR == 0 || iPAIR == 1 || iPAIR == 3 || iPAIR == 4 || iPAIR == 5 || iPAIR == 8 || iPAIR == 9 || iPAIR == 10 || iPAIR == 11 || iPAIR == 13 || iPAIR == 14 
      || iPAIR == 15 || iPAIR == 17 || iPAIR == 19 || iPAIR == 20 || iPAIR == 21)
      {
         PairDigits[iPAIR] = 5;
         PairMultipliers[iPAIR] = 10000; 
      }
      else
      {
         PairDigits[iPAIR] = 3;
         PairMultipliers[iPAIR] = 100;
      }
   }
   
   return(0);
}

string GetExecutionInfo()
{
   string str1, str2 = "";
   
   i = (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);
   switch(i)
   {
      case SYMBOL_TRADE_MODE_DISABLED:    str1 = "DISABLED";   break;
      case SYMBOL_TRADE_MODE_LONGONLY:    str1 = "LONG ONLY";  break;
      case SYMBOL_TRADE_MODE_SHORTONLY:   str1 = "SHORT ONLY"; break;
      case SYMBOL_TRADE_MODE_CLOSEONLY:   str1 = "CLOSE ONLY"; break;
      case SYMBOL_TRADE_MODE_FULL:        str1 = "FULL";       break;
   }
   
   i = (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_EXEMODE);
   switch(i)
   {
      case SYMBOL_TRADE_EXECUTION_REQUEST:   str2 = "BY REQUEST"; break;
      case SYMBOL_TRADE_EXECUTION_INSTANT:   str2 = "INSTANT";    break;
      case SYMBOL_TRADE_EXECUTION_MARKET:    str2 = "MARKET";     break;
      case SYMBOL_TRADE_EXECUTION_EXCHANGE:  str2 = "EXCHANGE";   break;
   }
   
   return(StringConcatenate("TRADE MODE: ", str1, " | EXMODE: ", str2));
}
