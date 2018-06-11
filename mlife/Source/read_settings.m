function [ Statistics, FileInfo, Fatigue] = read_settings( settingsFile, dataDirectory )
% Process an Crunch-style settings file.
%
% Syntax is:  [ Statistics, FileInfo, Fatigue] = read_settings( settingsFile, dataDirectory );
%
%
% Called by: mlife
% Calls to:  GetRoot, read_value


FileInfo = [];


% Open the settings file.

[UnPa, fileMessage] = fopen(settingsFile, 'rt' );
if ( UnPa < 1 )
   beep
   error( '%s: %s.', fileMessage, settingsFile );
end % if


% Read the settings file into a cell array.
% See if we are specifying channels using channel names or numbers.
% See if channel names are specified or found in the input files.

ParamFile = textscan( UnPa, '%s', 'delimiter', '\n' );

% see if we need to add the contents of an include file 
% An include file is used if the last line of the settings file has the following format:
% @include_filename         or
% @my_path\include_filename
% if a path is not given, then the location of the settings file is used to determine the location of the include file

lastLineStr = FindLastNonEmptyLine(ParamFile);
if ( strcmp(lastLineStr(1),'@') )
   
   includeFile = lastLineStr(2:end);
   [includePathStr, name, ext] = fileparts(includeFile);
   
   if ( isempty(includePathStr) )
      
      [settingsPathStr, ~, ~] = fileparts(settingsFile);
     
      includeFile = fullfile(settingsPathStr,[name ext]);
   end
   
   % open the include file 
   [fidInclude, fileMessage] = fopen(includeFile, 'rt' );
   if ( fidInclude < 1 )
      beep
      error( '%s: %s.', fileMessage, includeFile );
   end % if

   % read the include file contents and append to the ParamFile cell array
   includeFileContents = textscan( fidInclude, '%s', 'delimiter', '\n' );
   ParamFile = {[ParamFile{1}(1:end-1) ; includeFileContents{1}]};
   fclose( fidInclude );
end % if ( strcmp(lastLineStr(1),'@') )


EchoInp = cell2mat( read_value( ParamFile{1}{4}, 'logical', 1, 'EchoInp' , 'Echo input to <rootname>.echo as this file is being read.' ) );
if ( EchoInp )
   echoName =  sprintf('%s',GetRoot( settingsFile ), '.echo');
   [fidEcho, fileMessage] = fopen( echoName, 'wt' );
   if ( fidEcho < 0)
      error('%s: %s.',fileMessage, echoName);
   end
   fprintf( fidEcho, 'Echoing contents of "%s".\n', settingsFile );
   for PLine=2:4
      fprintf( fidEcho, '%s\n', ParamFile{1}{PLine} );
   end % for
else
   fidEcho = 0;
end % if



StrNames  = cell2mat( read_value( ParamFile{1}{ 5}, 'logical', 1, '' , '', fidEcho ) );
NumChans  = cell2mat( read_value( ParamFile{1}{14}, 'integer', 1, '' , '' ) );


% See if the user supplied channel names in the parameter-input file or if
% we should parse them from the last data file.
%TODO: should that be first or last
if ( NumChans == 0 )
   FileInfo.UserNames = false;
elseif ( NumChans > 0 )
   FileInfo.UserNames = true;
else
   beep
   error( '  In the Input-Data Layout section of the parameter file, NumChans must be >= 0.' );
end % if


% Determine the number of calculated channels and where the list of the begins.

NumCChan = cell2mat( read_value( ParamFile{1}{NumChans+17}, 'integer', 1, '' , '' ) );
FirstCC  = NumChans + 20;

% Determine the number of load rose channels and where the list of the begins.
NumLRChans          = 0;
FileInfo.nLoadRoses = cell2mat( read_value( ParamFile{1}{NumChans+21+NumCChan}, 'integer', 1, '' , '' ) );

if ( FileInfo.nLoadRoses > 0 )
   FirstLR       = NumChans+22+NumCChan;
   
   for iRose=1:FileInfo.nLoadRoses
      temp       = textscan( ParamFile{1}{FirstLR+iRose}, '%q %q %q %q %f', 1 );
      NumLRChans = NumLRChans + temp{5};
   end   
   
end % if

if ( FileInfo.UserNames )
      
   % Channel names specified in the parameter file.
   % Read them from the cell array containing the parameter file text.
   
   ChanNames = cell( NumChans+NumCChan + NumLRChans, 1 );
   
   for Chan=1:NumChans
      temp            = textscan( ParamFile{1}{Chan+15}, '%q', 1 );
      %         ChanNames{Chan} = [ '$', cell2mat( temp{1} ) ];
      ChanNames{Chan} = cell2mat( temp{1} );
   end % for Chan
   
else
      
   % Channel names specified in the header(s) of the data file(s).
   % Determine the line number of the data file(s) that contain the channel names.
   % Find the last specified data file.  Open it, and read the channel names.
   
   NamesLine = cell2mat( read_value( ParamFile{1}{11}, 'integer', 1, '' , '' ) );
   
   
   %TODO: Make it so MCrunch uses default name (e.g., "Chan1") if we are getting info from
   %      the data files and NamesLine is set to zero.
   
   if ( NamesLine == 0 )
      beep
      error( '  You must have a line with names (NamesLine) if you want to get information from the data files.' );
   end % if
   
   for PLine=1:size( ParamFile{1}, 1 )
      if ( ~isempty( strfind( ParamFile{1}{PLine}, 'Input Files' ) ) )
         firstFileLine = PLine + 3;
         break
      end % if
   end % for PLine
   
   dataFileName     = cell2mat( read_value( ParamFile{1}{firstFileLine}, 'string' , 1, '', '' ) );
   if (nargin > 1)
      dataDirectory = validate_path(dataDirectory);
      dataFileName  = sprintf('%s', dataDirectory, dataFileName);
   end
   [fidData, fileMessage] = fopen( dataFileName, 'rt' );
   
   if ( fidData < 0 )
      beep;
      error( '%s: %s.', fileMessage, dataFileName);
      %HdlDgl = warndlg( sprintf( 'Please close "%s" if it is open in another program such as Excel.', dataFileName ), 'File Locked!', 'replace' );
      %uiwait( HdlDgl );
      %fidData = fopen( dataFileName, 'rt' );
   end % if
   
   HeadLines  = textscan( fidData, '%s', NamesLine, 'delimiter', '\n' );
   fclose( fidData );
   temp       = textscan( HeadLines{1}{NamesLine}, '%s' );
   NumChans   = size( temp{1}, 1 );
   %      NumChansSN = NumChans;
   ChanNames  = cell( 1, NumChans );
   
   for Ch=1:NumChans
      %         ChanNames{Ch} = [ '$', temp{1}{Ch} ];
      ChanNames{Ch} = temp{1}{Ch};
   end % for Ch
   
end % if ( FileInfo.UserNames )


   % Add the calculated channel names to the list of channels.

for Ch=1:NumCChan
   ChanNames{NumChans+Ch} = cell2mat( read_value( ParamFile{1}{FirstCC+Ch-1}, 'string' , 1, '' , '' ) );
end % for



 
 
   % Add Load Roses channels

i = 1;
for iRose=1:FileInfo.nLoadRoses
   temp = textscan( ParamFile{1}{FirstLR+iRose}, '%q %q %q %q %f', 1 );
   % need to echo these lines
   for iChan = 1:temp{5}
      ChanNames{NumChans+NumCChan+i} = sprintf('%s_%d',char(temp{1}),iChan);
      i = i+1;
   end
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 
 
 
 
TotChans = NumChans + NumCChan + NumLRChans;


if ( StrNames )
   
   
   % Create an cell array of index strings.
   
   ChanInds = cell( TotChans, 1 );
   
   for Ch=1:TotChans
      ChanInds{Ch} = num2str( Ch, '%u' );
   end % for Ch
   
   
   % Processing the ParamFile cell array, replace all the "$<ChanName>$" strings with
   % the appropriate indices.
   
   for Ch=1:TotChans
      for PLine=1:size( ParamFile{1}, 1 )
         ParamFile{1}{PLine} = strrep( ParamFile{1}{PLine}, [ '$', ChanNames{Ch}, '$' ], ChanInds{Ch} );
      end % for PLine
   end % for Ch
   
end % if (StrNames)




%=================================================================
% Skip the header.  Read the job options.
%=================================================================



PLine = 4;

% The following line is not used, yet but still read it so it can be echoed
OutData            = cell2mat( read_value( ParamFile{1}{PLine+2}, 'logical', 1, 'OutData' , 'Output modified data array after scaling and calculated channels?', fidEcho  ) );

FileInfo.RealFmt   = cell2mat( read_value( ParamFile{1}{PLine+3}, 'string' , 1, 'RealFmt' , 'Format for outputting floating-point values.', fidEcho                      ) );
FileInfo.RootName  = cell2mat( read_value( ParamFile{1}{PLine+4}, 'string' , 1, 'AggRoot' , 'Root name for aggregate output files.', fidEcho                             ) );

%FileInfo.StrFmt  = [ '%' , regexp(FileInfo.RealFmt,'\d*', 'ignorecase', 'match', 'once'), 's' ];
%FileInfo.StrFmtL = [ '%-', regexp(FileInfo.RealFmt,'\d*', 'ignorecase', 'match', 'once'), 's' ];
PLine = PLine + 5;


%=================================================================
% Read the layout of the input data.
%=================================================================

if ( EchoInp )
   fprintf( fidEcho, '%s\n', ParamFile{1}{PLine} );
end % if

FileInfo.TitleLine     = cell2mat( read_value( ParamFile{1}{PLine+1}, 'integer', 1, 'TitleLine'    , 'The row with the file title on it.', fidEcho    ) );
FileInfo.NamesLine     = cell2mat( read_value( ParamFile{1}{PLine+2}, 'integer', 1, 'NamesLine'    , 'The row with the channel names on it.', fidEcho ) );
FileInfo.UnitsLine     = cell2mat( read_value( ParamFile{1}{PLine+3}, 'integer', 1, 'UnitsLine'    , 'The row with the channel units on it.', fidEcho ) );
FileInfo.FirstDataLine = cell2mat( read_value( ParamFile{1}{PLine+4}, 'integer', 1, 'FirstDataLine', 'The first row of data.', fidEcho                ) );


if ( FileInfo.NamesLine > 0 )
   FileInfo.AutoNames = true;
   FileInfo.HaveNames = true;
else
   FileInfo.AutoNames = false;
   FileInfo.HaveNames = false;
end % if

if ( FileInfo.UnitsLine > 0 )
   FileInfo.AutoUnits = true;
   FileInfo.HaveUnits = true;
else
   FileInfo.AutoUnits = false;
   FileInfo.HaveUnits = false;
end % if

% Repeat this for echoing purposes
NumChans = cell2mat( read_value( ParamFile{1}{PLine+5}, 'integer', 1, 'NumChans', 'The number of channels in each input file.', fidEcho ) );

PLine = PLine + 6;

if ( EchoInp )
   fprintf( fidEcho, '%s\n', ParamFile{1}{PLine} );
end % if

if ( FileInfo.UserNames )
   
   FileInfo.HaveNames   = true;
   FileInfo.HaveUnits   = true;
   FileInfo.doScaleData = true;
   
   for Chan=1:NumChans

      temp = textscan( ParamFile{1}{PLine+Chan}, '%q %q %f %f %d', 1 );

      FileInfo.Names  (Chan) = temp{1};
      FileInfo.Units  (Chan) = temp{2};
      FileInfo.Scales (Chan) = temp{3};
      FileInfo.Offsets(Chan) = temp{4};
      if ~( isempty(temp{5}) )
         FileInfo.PSFtype(Chan) = temp{5};   % This is new  need to verify, what if nothing is present?
      else
         FileInfo.PSFtype(Chan) = 0;
      end
      if ( EchoInp )
         fprintf( fidEcho, '%s\n', ParamFile{1}{PLine+Chan} );
      end % if
      
   end % for Chan
   
   PLine = PLine + NumChans + 1;
   
else
  
   FileInfo.doScaleData = false;
   FileInfo.Scales =0;
   FileInfo.Offsets=0;
   FileInfo.PSFtype=0;
   PLine = PLine + 1;
   
end % if FileInfo.UserNames


%=================================================================
% Read the calculated-channels information.
%=================================================================

if ( EchoInp )
   fprintf( fidEcho, '%s\n', ParamFile{1}{PLine} );
end % if

% Repeat the following line for echoing purposes
NumCChan = cell2mat( read_value( ParamFile{1}{PLine+1}, 'integer', 1, 'NumCChan', 'The number calculated channels to generate.', fidEcho       ) );
%   TotChans = NumChans + NumCChan;

Seed     = cell2mat( read_value( ParamFile{1}{PLine+2}, 'integer', 1, 'Seed'    , 'The integer seed for the random number generator.', fidEcho ) );
PLine    = PLine + 3;

if ( EchoInp )
   fprintf( fidEcho, '%s\n', ParamFile{1}{PLine} );
end % if

FileInfo.CalcChan = repmat( struct( 'Name','', 'Units','', 'Eqn','' ), 1, double( NumCChan ) );

for Chan=1:NumCChan
   temp = read_value( ParamFile{1}{PLine+Chan}, 'string' , 3, '', '', fidEcho );
   FileInfo.CalcChan(Chan).Name  = temp{1};
   FileInfo.Names(NumChans+Chan) = temp(1);
   FileInfo.CalcChan(Chan).Units = temp{2};
   FileInfo.Units(NumChans+Chan) = temp(2);
   FileInfo.CalcChan(Chan).Eqn   = temp{3};
end

PLine = PLine + NumCChan + 1;


%=================================================================
% Read the load roses information.
%=================================================================

if ( EchoInp )
   fprintf( fidEcho, '%s\n', ParamFile{1}{PLine} );
end % if

% Repeat the following line for echoing purposes
FileInfo.nLoadRoses = cell2mat( read_value( ParamFile{1}{PLine+1}, 'integer', 1, 'nLoadRoses', 'The number of load roses to generate.', fidEcho       ) );

PLine = PLine + 2;

if ( EchoInp )
   fprintf( fidEcho, '%s\n', ParamFile{1}{PLine} );
end % if



FileInfo.LoadRoses = repmat( struct( 'Name','', 'Channel1','', 'Channel2','','nSectors','' ), 1, double( FileInfo.nLoadRoses ) );

for iRose=1:FileInfo.nLoadRoses
   temp = textscan( ParamFile{1}{PLine+iRose}, '%q %q %f %f %f', 1 );
   if ( EchoInp )
      fprintf( fidEcho, '%s\n', ParamFile{1}{PLine+iRose} );
   end % if

   % need to echo these lines
   FileInfo.LoadRoses(iRose).Name       = temp{1};
   FileInfo.LoadRoses(iRose).Units      = temp{2};
   FileInfo.LoadRoses(iRose).Channel1   = temp{3};
   FileInfo.LoadRoses(iRose).Channel2   = temp{4};
   FileInfo.LoadRoses(iRose).nSectors   = temp{5};
end

PLine = PLine + FileInfo.nLoadRoses + 1;

% Create all of the load roses channels  NOTE:  This probably should be done in process_mlife_inputs.m!!!!!
numLoadRoseChan = 0;
for iRose=1:FileInfo.nLoadRoses
   for iCh=1:FileInfo.LoadRoses(iRose).nSectors
      FileInfo.Names(NumChans+NumCChan+iCh+numLoadRoseChan) = {[FileInfo.LoadRoses(iRose).Name{1} sprintf('_%d',iCh)]};
      FileInfo.Units(NumChans+NumCChan+iCh+numLoadRoseChan) = FileInfo.LoadRoses(iRose).Units;   
   end
   numLoadRoseChan = numLoadRoseChan + FileInfo.LoadRoses(iRose).nSectors;
end

%=================================================================
% Read the information for time and wind-speed channels.
%=================================================================

if ( EchoInp )
   fprintf( fidEcho, '%s\n', ParamFile{1}{PLine} );
end % if

FileInfo.TimeChan = cell2mat( read_value( ParamFile{1}{PLine+1}, 'integer', 1, 'TimeChan', 'The channel containing time.', fidEcho    ) );
FileInfo.WSChan   = cell2mat( read_value( ParamFile{1}{PLine+2}, 'integer', 1, 'WSChan' , 'The primary wind-speed channel.', fidEcho ) );

PLine = PLine + 3;


%=================================================================
% Read the information for statistics 
%=================================================================

if ( EchoInp )
   fprintf( fidEcho, '%s\n', ParamFile{1}{PLine} );
end % if

Statistics.DoStats      = cell2mat( read_value( ParamFile{1}{PLine+1}, 'logical', 1, 'DoStats'   , 'Generate statistics of all the channels.', fidEcho                                         ) );
Statistics.WrStatsTxt   = cell2mat( read_value( ParamFile{1}{PLine+2}, 'logical', 1, 'WrStatsTxt', 'Write a text file of statistics for each input file and the aggregate of all of them.', fidEcho ) );
Statistics.WrStatsXLS   = cell2mat( read_value( ParamFile{1}{PLine+3}, 'logical', 1, 'WrStatsXLS', 'Write an Excel file of statistics for each input file and the aggregate of all of them.', fidEcho ) );
NumSFChans   = cell2mat( read_value( ParamFile{1}{PLine+4}, 'integer', 1, 'NumSFChans', 'Number of channels that will have summary statistics generated for them.', fidEcho         ) );
Statistics.SumStatChans = zeros( 1, NumSFChans );

if ( NumSFChans > 0 )
   
   temp = read_value( ParamFile{1}{PLine+5}, 'integer', NumSFChans, 'SFChans', 'List of channels that will have summary statistics generated for them.  Must number NumSFChans.', fidEcho );
   
   for Chan=1:NumSFChans
      Statistics.SumStatChans(Chan) = temp{Chan};
   end % for Chan
   
else
   
   if ( EchoInp )
      fprintf( fidEcho, '%s\n', ParamFile{1}{PLine+5} );
   end % if
   
end % if ( NumSFChans > 0 )

PLine = PLine + 6;

%=================================================================
% Read the information for fatigue.
%=================================================================

Fatigue = [];

if ( EchoInp )
   fprintf( fidEcho, '%s\n', ParamFile{1}{PLine} );
end % if


Fatigue.nFatigueChannels    = cell2mat( read_value( ParamFile{1}{PLine+01}, 'integer', 1, 'nFatigueChannels', 'The number of rainflow channels.', fidEcho                                                              ) );
Fatigue.FiltRatio           = cell2mat( read_value( ParamFile{1}{PLine+02}, 'float'  , 1, 'FiltRatio'  , 'The fraction of the maximum range of each channel used as a cutoff range for the racetrack filter.', fidEcho ) );
Fatigue.DesignLife          = cell2mat( read_value( ParamFile{1}{PLine+03}, 'float'  , 1, 'DesignLife' , 'Number of seconds in the rainflow counting period.', fidEcho                                                 ) );
Fatigue.Availability        = cell2mat( read_value( ParamFile{1}{PLine+04}, 'float'  , 1, 'Availability' , 'Fraction of the design life the turbine is operating when winds are between Vin and Vout', fidEcho         ) );
Fatigue.BinCycles           = cell2mat( read_value( ParamFile{1}{PLine+05}, 'logical', 1, 'BinCycles'  , 'Bin the rainflow cycles?', fidEcho                                                                           ) );
Fatigue.UCMult              = cell2mat( read_value( ParamFile{1}{PLine+06}, 'float'  , 1, 'UCMult'     , 'Multiplier for binning unclosed cycles.', fidEcho                                                            ) );
Fatigue.DoShortTerm         = cell2mat( read_value( ParamFile{1}{PLine+07}, 'logical', 1, 'DoShortTerm' , 'Compute simple (unweighted) damage-equivalent loads and damage rates.', fidEcho                             ) );
Fatigue.DoLife              = cell2mat( read_value( ParamFile{1}{PLine+08}, 'logical', 1, 'DoLife'     , 'Do lifetime-related calculations?', fidEcho                                                                  ) );
Fatigue.DoAggregate         = cell2mat( read_value( ParamFile{1}{PLine+09}, 'logical', 1, 'DoAggregate', 'Compute a DELs and a damage result based on an aggregate of all the input files', fidEcho                    ) );
Fatigue.weibullShapeFactor  = cell2mat( read_value( ParamFile{1}{PLine+10}, 'float'  , 1, 'weibullShapeFactor'  , 'Weibull shape factor. If WeibullShape=2, enter the mean wind speed for WeibullScale.', fidEcho      ) );
temp                        = cell2mat( read_value( ParamFile{1}{PLine+11}, 'float'  , 1, 'weibullScaleFactor'  , 'Weibull scale factor. If WeibullShape<>2.  Otherwise, enter the mean wind speed.', fidEcho          ) );

if ( Fatigue.weibullShapeFactor ==2 )
   Fatigue.weibullMeanWS      = temp;
else
   Fatigue.weibullScaleFactor = temp;
end

Fatigue.WSin                = cell2mat( read_value( ParamFile{1}{PLine+12}, 'float'  , 1, 'WSin'       , 'Cut-in wind speed for the turbine.', fidEcho                                                                 ) );
Fatigue.WSout               = cell2mat( read_value( ParamFile{1}{PLine+13}, 'float'  , 1, 'WSout'      , 'Cut-out wind speed for the turbine.', fidEcho                                                                ) );
Fatigue.WSmax               = cell2mat( read_value( ParamFile{1}{PLine+14}, 'float'  , 1, 'WSmax'      , 'Maximum  value for the wind-speed bins.', fidEcho                                                            ) );
Fatigue.WSMaxBinSize        = cell2mat( read_value( ParamFile{1}{PLine+15}, 'float'  , 1, 'WSMaxBinSize'   , 'The max width of a wind-speed bin.', fidEcho                                                             ) );
Fatigue.WrShortTermTxt      = cell2mat( read_value( ParamFile{1}{PLine+16}, 'logical', 1, 'WrShortTermTxt'  , 'Write DELs to plain-text files?', fidEcho                                                               ) );
Fatigue.WrShortTermXLS      = cell2mat( read_value( ParamFile{1}{PLine+17}, 'logical', 1, 'WrShortTermXLS'  , 'Write DELs to an Excel workbook?', fidEcho                                                              ) );
Fatigue.WrLifeTxt           = cell2mat( read_value( ParamFile{1}{PLine+18}, 'logical', 1, 'WrLifeTXT'  , 'Write lifetime results to plain-text files?', fidEcho                                                        ) );
Fatigue.WrLifeXLS           = cell2mat( read_value( ParamFile{1}{PLine+19}, 'logical', 1, 'WrLifeXLS'  , 'Write lifetime results to an Excel workbook?', fidEcho                                                       ) );
Fatigue.EquivalentFrequency = cell2mat( read_value( ParamFile{1}{PLine+20}, 'float'  , 1, 'EquivalentFrequency'  , 'The frequency of the damage equivalent load (Hz).', fidEcho                                        ) );
Fatigue.DEL_AsRange         = cell2mat( read_value( ParamFile{1}{PLine+21}, 'logical', 1, 'DEL_AsRange', 'true = report DELs as a range value,  false = report as a one-sided amplitude', fidEcho                      ) );
Fatigue.DEL_Type            = cell2mat( read_value( ParamFile{1}{PLine+22}, 'integer', 1, 'DEL_Type'   , '1 = fixed mean, 2 = zero mean, 3 = compute both', fidEcho                                                    ) );
Fatigue.GoodmanFlag         = cell2mat( read_value( ParamFile{1}{PLine+23}, 'integer', 1, 'GoodmanFlag', '0 = no Goodman, 1 = use Goodman, 2 = compute with and without', fidEcho                                      ) );

PLine = PLine + 24;

if ( EchoInp )
   fprintf( fidEcho, '%s\n', ParamFile{1}{PLine} );
end
   

for Ch=1:Fatigue.nFatigueChannels

   % First, see how many S/N Slopes were entered.  That will determine the format.  Then, do the real read.

   temp = textscan( ParamFile{1}{PLine+Ch}, '%d %f', 1 );

   if ( EchoInp )
      fprintf( fidEcho, '%s\n', ParamFile{1}{PLine+Ch} );
   end % if

   Fmt = [ '%d %f', repmat( ' %f', 1, temp{2} ), ' %s %f %s %f' ];

   temp = textscan( ParamFile{1}{PLine+Ch}, Fmt, 1 );

   Fatigue.ChanInfo(Ch).Chan    = temp{1};
   Fatigue.ChanInfo(Ch).NSlopes = temp{2};

   for Slope=1:Fatigue.ChanInfo(Ch).NSlopes
      Fatigue.ChanInfo(Ch).SNslopes(Slope) = temp{Slope+2};
   end % for Slope

   if ( Fatigue.BinCycles )
      
      Fatigue.ChanInfo(Ch).BinFlag  = cell2mat(temp{Fatigue.ChanInfo(Ch).NSlopes+3});
      Fatigue.ChanInfo(Ch).BinVal   = temp{Fatigue.ChanInfo(Ch).NSlopes+4};
      
   end % if

   %TODO: GJH  Check the following two lines for possible bug
   %introduction...
   Fatigue.ChanInfo(Ch).TypeLMF = temp{Fatigue.ChanInfo(Ch).NSlopes+5}{1};
   Fatigue.ChanInfo(Ch).LUlt    = temp{Fatigue.ChanInfo(Ch).NSlopes+6};


end % for Ch


PLine = PLine + Fatigue.nFatigueChannels + 1;

Fatigue.nGroups = cell2mat( read_value( ParamFile{1}{PLine}, 'integer', 1, 'nGroups', ' ', fidEcho                      ) );

if ( EchoInp )
   fprintf( fidEcho, '%s\n', ParamFile{1}{PLine+1} );
end % if

if ( Fatigue.nGroups > 0 )
   
   for iGroup=1:Fatigue.nGroups
      
      if ( EchoInp )
         fprintf( fidEcho, '%s\n', ParamFile{1}{PLine+1+iGroup} );
      end % if
      
      temp = textscan( ParamFile{1}{PLine+1+iGroup}, '%q %d', 1 );
      Fmt = [ '%q', '%d', repmat( ' %d', 1, temp{2} ) ];
      
      temp = textscan( ParamFile{1}{PLine+1+iGroup}, Fmt, 1 );
      Fatigue.Groups(iGroup).name = temp{1};
      nGroupChannels              = temp{2};

      for jCh=1:nGroupChannels
         Fatigue.Groups(iGroup).channelIndices(jCh) = temp{2+jCh};
      end % for jCh
  
   end  % for iGroup
   PLine = PLine + Fatigue.nGroups ;

end

PLine = PLine + 2;


%=================================================================
% Read the list of input files.
% There are three required sections:  Normal Operation, Idling, Discrete Events 
%=================================================================
   FileInfo.DLCs =  repmat( struct( 'NumFiles',0, 'PSF',zeros(1,4,'single'),'DLC_Name','' ), 1, 3 );
   
   if ( EchoInp )
      fprintf( fidEcho, '%s\n', ParamFile{1}{PLine} );
   end % if
   PLine = PLine + 1;
   
   FileInfo.FileFormat = cell2mat( read_value( ParamFile{1}{PLine}, 'integer', 1, 'FileFormat', 'Flag determining input file format.  1 = ascii, 2 = binary', fidEcho                      ) );
   PLine = PLine + 1;
   
   totalFiles = 0;
   FileList1  = [];
   FileList2  = [];
   FileList3  = [];
   
   
      %  Section 1 : Normal Operation, Weibull and Availability weighted
   
   if ( EchoInp )
      fprintf( fidEcho, '%s\n', ParamFile{1}{PLine} );
   end % if
   
   temp = textscan( ParamFile{1}{PLine}, '%d %f %f %f %f', 1 );
   FileInfo.DLCs(1).NumFiles   = temp{1};
   
   if ( FileInfo.DLCs(1).NumFiles > 0 )
      
      FileList1                   = cell( FileInfo.DLCs(1).NumFiles, 1 );
      FileInfo.DLCs(1).PSF(1)     = temp{2};
      FileInfo.DLCs(1).PSF(2)     = temp{3};
      FileInfo.DLCs(1).PSF(3)     = temp{4};
      FileInfo.DLCs(1).PSF(4)     = temp{5};
      iCount                      = 1;
      
      for iFile=1:FileInfo.DLCs(1).NumFiles
         FileList1{iCount,1} = cell2mat( read_value( ParamFile{1}{PLine+iFile}, 'string' , 1, '', '', fidEcho ) );
         iCount              = iCount + 1;
      end % for File
      
      totalFiles = totalFiles + FileInfo.DLCs(1).NumFiles;
      PLine      = PLine + FileInfo.DLCs(1).NumFiles + 1;
      
   else
         % no files in this DLC
      PLine = PLine + 1;
   end
   
   
      %  Section 2 : Normal Operation, Weibull and Availability weighted
      
   if ( EchoInp )
      fprintf( fidEcho, '%s\n', ParamFile{1}{PLine} );
   end % if
   
   temp = textscan( ParamFile{1}{PLine}, '%d %f %f %f %f', 1 );
   FileInfo.DLCs(2).NumFiles   = temp{1};
   
   if ( FileInfo.DLCs(2).NumFiles > 0 )
      
      FileList2                   = cell( FileInfo.DLCs(2).NumFiles, 1 );
      FileInfo.DLCs(2).PSF(1)     = temp{2};
      FileInfo.DLCs(2).PSF(2)     = temp{3};
      FileInfo.DLCs(2).PSF(3)     = temp{4};
      FileInfo.DLCs(2).PSF(4)     = temp{5};
      iCount                      = 1;
      
      for iFile=1:FileInfo.DLCs(2).NumFiles
         FileList2{iCount,1} = cell2mat( read_value( ParamFile{1}{PLine+iFile}, 'string' , 1, '', '', fidEcho ) );
         iCount              = iCount + 1;
      end % for File
      totalFiles = totalFiles + FileInfo.DLCs(2).NumFiles;     
      FileList = [FileList1; FileList2];
      
   else
      FileList = FileList1;
   end
   
   PLine = PLine + FileInfo.DLCs(2).NumFiles + 1;
   
   
      %  Section 3 : Discrete events, not weighted
      % DLC_Occurrences indicates how many times the discrete event occurs over the design lifetime
      
   FileInfo.DLC_Occurrences = [];
   
   if ( EchoInp )
      fprintf( fidEcho, '%s\n', ParamFile{1}{PLine} );
   end % if
   
   temp = textscan( ParamFile{1}{PLine}, '%d %f %f %f %f', 1 );
   FileInfo.DLCs(3).NumFiles   = temp{1};
   
   if ( FileInfo.DLCs(3).NumFiles > 0 )
      
      FileList3                   = cell( FileInfo.DLCs(3).NumFiles, 1 );
      FileInfo.DLCs(3).PSF(1)     = temp{2};
      FileInfo.DLCs(3).PSF(2)     = temp{3};
      FileInfo.DLCs(3).PSF(3)     = temp{4};
      FileInfo.DLCs(3).PSF(4)     = temp{5};
      FileInfo.FileOccurances     = ones(FileInfo.DLCs(3).NumFiles);
      iCount                      = 1;
      
      for iFile=1:FileInfo.DLCs(3).NumFiles
         %temp = textscan( ParamFile{1}{PLine + iFile}, '%d %s', 1 );
         temp = read_value( ParamFile{1}{PLine+iFile}, 'string' , 2, '', '', fidEcho );
         FileInfo.DLC_Occurrences(iFile) = str2num(temp{1});
         
         FileList3{iCount,1} = temp{2}; % cell2mat( read_value( ParamFile{1}{PLine+iFile}, 'string' , 2, '', '', fidEcho ) );
         iCount = iCount + 1;
      end % for File
      
      totalFiles = totalFiles + FileInfo.DLCs(3).NumFiles;     
      FileList = [FileList; FileList3];
  
   end
   
   PLine = PLine + FileInfo.DLCs(3).NumFiles + 1;
   
   FileInfo.FileName = FileList;
   FileInfo.nFiles = totalFiles;
   FileInfo.nChannels = double(TotChans);
   
      % Echo the EOF line
   if ( EchoInp )
      fprintf( fidEcho, '%s\n', ParamFile{1}{PLine} );
      fclose( fidEcho );
   end % if
   fclose( UnPa );




% NOTE:  Removing this requirement per discussions with Jason Jonkman and
% Marshall Buhl.  
% if ( DoFatigue && Fatigue.DoLife && nFiles == 1 )
%    beep;
%    error( '  It is not meaningful to do fatigue-life calculations with only a single file.' );
% end % if


return

   % Internal Functions
   % These are used to locate the last non-empty line in the settings file
   
   function str  = FindLastNonEmptyLine(ParamFile)
      lineNumber = length(ParamFile{1});
      str = RecursiveFindLastNonEmptyLine(ParamFile, lineNumber);
   end

   function str = RecursiveFindLastNonEmptyLine(ParamFile, lineNumber)
         str =  ParamFile{1}{lineNumber};
      if (isempty(str))
         str = RecursiveFindLastNonEmptyLine(ParamFile, lineNumber-1);
      end
   end
      
end %   read_settings()
