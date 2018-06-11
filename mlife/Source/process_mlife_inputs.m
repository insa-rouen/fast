function [FileInfo, Statistics, Fatigue] = process_mlife_inputs( FileInfo, Statistics, Fatigue, dataDirectory )

% Process the raw inputs which came from either a settings file or input
% parameters to the mlife function
% 
% Called by: mlife
% Calls to : load_file_header
%

   FileInfo.StrFmt  = [ '%' , regexp(FileInfo.RealFmt,'\d*', 'ignorecase', 'match', 'once'), 's' ];
   FileInfo.StrFmtL = [ '%-', regexp(FileInfo.RealFmt,'\d*', 'ignorecase', 'match', 'once'), 's' ];

   
      % Determine the values of the AutoNames and HaveNames flags
      % If FileInfo.AutoNames is true, then populate the names array by reading channel names from input file
      % If FileInfo.AutoUnits is true, then populate the units array by reading channel units from input file
      
   if ( FileInfo.NamesLine > 0 )
      FileInfo.AutoNames = true;
      FileInfo.HaveNames = true;
   else
      FileInfo.AutoNames = false;
      FileInfo.HaveNames = false;
   end % if FileInfo.NamesLine > 0

   if ( FileInfo.UnitsLine > 0 )
      FileInfo.AutoUnits = true;
      FileInfo.HaveUnits = true;
   else
      FileInfo.AutoUnits = false;
      FileInfo.HaveUnits = false;
   end % if FileInfo.UnitsLine > 0

   if (FileInfo.nFiles == 0)
      beep
      error( '  MLife must be given at least one input file.');
   end
   
   
      % Strip off any file path and only store the base file name.
      
   for iFile=1:FileInfo.nFiles
      
      if (~isempty(dataDirectory))
         
         fileseps = strfind(FileInfo.FileName{iFile,1},filesep);
         
         if ( isempty(fileseps) || fileseps(1) == length(FileInfo.FileName{iFile,1}) )
            FileInfo.FileName{iFile,1} = sprintf('%s', dataDirectory, FileInfo.FileName{iFile,1});
         end 
         
      end
      
   end % for File

   
   
   if ( FileInfo.HaveNames && ( FileInfo.TitleLine >= FileInfo.NamesLine ) )
      beep
      error( '  NamesLine (%d) must be greater than TitleLine (%d) unless NamesLine is zero.', FileInfo.NamesLine, FileInfo.TitleLine );
   end % if

   if ( ( FileInfo.UnitsLine > 0 ) && ( FileInfo.TitleLine >= FileInfo.UnitsLine ) )
      beep
      error( '  UnitsLine (%d) must be greater than TitleLine (%d) unless UnitsLine is zero.', FileInfo.UnitsLine, FileInfo.TitleLine );
   end % if

   if ( ( FileInfo.UnitsLine > 0 ) && ( FileInfo.NamesLine >= FileInfo.UnitsLine ) )
      beep
      error( '  UnitsLine (%d) must be greater than NamesLine (%d) unless UnitsLine is zero.', FileInfo.UnitsLine, FileInfo.NamesLine );
   end % if

   if ( FileInfo.TitleLine >= FileInfo.FirstDataLine )
      beep
      error( '  FirstDataLine (%d) must be greater than TitleLine (%d).', FileInfo.FirstDataLine, FileInfo.TitleLine );
   end % if

   if ( FileInfo.NamesLine >= FileInfo.FirstDataLine )
      beep
      error( '  FirstDataLine (%d) must be greater than NamesLine (%d).', FileInfo.FirstDataLine, FileInfo.NamesLine );
   end % if

   if ( FileInfo.UnitsLine >= FileInfo.FirstDataLine )
      beep
      error( '  FirstDataLine (%d) must be greater than UnitsLine (%d).', FileInfo.FirstDataLine, FileInfo.UnitsLine );
   end % if

   if ( Fatigue.DoLife || Fatigue.DoShortTerm )
      doFatigue = true;
   else
      doFatigue = false;
   end
   
   if ( Fatigue.DoLife && ( Fatigue.DesignLife <= 0 ) )
      beep;
      error( '  The design lifetime must be greater than zero.' );
   end % if
   
   if ( Fatigue.DoLife && ( Fatigue.weibullShapeFactor <= 0 ) )
      beep;
      error( '  The Weibull shape factor must be greater than zero.' );
   end % if
   if ( Fatigue.DoLife && Fatigue.weibullShapeFactor ==2 )
      if ( Fatigue.DoLife && ( Fatigue.weibullMeanWS <= 0 ) )
         beep;
         error( '  The mean of the wind speed distribution (WeibullScale) must be greater than zero.' );
      end % if
   else
      if ( Fatigue.DoLife && ( Fatigue.weibullScaleFactor <= 0 ) )
         beep;
         error( '  The scale factor of the wind speed distribution (WeibullScale) must be greater than zero.' );
      end % if
   end
      
   if ( Fatigue.DoLife && ( Fatigue.Availability < 0 || Fatigue.Availability > 1 ) )
      beep;
      error( '  The availability must be greater or equal to zero and less than or equal to 1.' );
   end
   
   if ( doFatigue && ( Fatigue.UCMult < 0 || Fatigue.UCMult > 1 ) )
      beep;
      error( '  The unclosed cycle multiplier (UCMult) must be greater or equal to zero and less than or equal to 1.' );
   end
   
   if ( doFatigue && ( Fatigue.FiltRatio < 0 || Fatigue.FiltRatio > 1 ) )
      beep;
      error( '  The racetrack filter ratio(FiltRatio) must be greater or equal to zero and less than or equal to 1.' );
   end
   
   if ( Fatigue.DoLife && ( Fatigue.WSin < 0 ) )
      beep;
      error( '  The cut-in wind speed (WSin) must be greater or equal to zero.' );
   end % if
   
   if ( Fatigue.DoLife && ( ( Fatigue.WSout <= Fatigue.WSin ) || ( Fatigue.WSout <= 0 ) ) )
      beep;
      error( '  The cut-out wind speed (WSout) must be greater than zero and greater than the cut-in windspeed (WSin).' );
   end % if
   
   if ( Fatigue.DoLife && ( ( Fatigue.WSmax <= Fatigue.WSout ) || ( Fatigue.WSmax <= 0 ) ) )
      beep;
      error( '  The maximum wind speed for the wind speed bins (WSmax) must be greater than zero and greater than the cut-out windspeed (WSout).' );
   end % if
   
   if ( Fatigue.DoLife && ( Fatigue.WSMaxBinSize <= 0 ) )
      beep;
      error( '  The maximum wind speed bin size (WSMaxBinSize) must be greater than to zero.' );
   end % if
    
   if ( doFatigue && ( Fatigue.EquivalentFrequency <= 0 ) )
      beep;
      error( '  The equivalent frequency (EquivalentFrequency) must be greater than to zero.' );
   end % if
   
   if ( Fatigue.DoLife && ( FileInfo.WSChan == 0 ) )
      beep;
      error( '  For fatigue, you cannot do lifetime calculations without specifying the wind-speed channel (WSChan).' );
   end % if
   
   if ( Fatigue.GoodmanFlag < 0 || Fatigue.GoodmanFlag > 2 )
      beep;
      error( '  The GoodmanFlag must be set to 0, 1, or 2.' );
   end
   
   
      % Load names and units from file if necessary
      
   if ( ~FileInfo.UserNames)
      [names, units] = load_file_header(FileInfo.FileName{1}, FileInfo.FileFormat, FileInfo.NamesLine, FileInfo.UnitsLine, ...
                                        FileInfo.FirstDataLine, FileInfo.AutoNames, FileInfo.AutoUnits, FileInfo.HaveNames, ...
                                        FileInfo.HaveUnits, FileInfo.CalcChan);
      FileInfo.Names = names;
      FileInfo.Units = units;
      
   end 
   
      % this is for testing only
   if ( ~isfield(Fatigue,'useWeibull') )
      Fatigue.useWeibull         = true;
   end
 
   
      % Set up the channel-based data
      % the allSlopes array in the end will contain a list of all unique S/N slope values across all fatigue channels

   for iCh=1:Fatigue.nFatigueChannels
   
      if ( doFatigue && ( ( Fatigue.ChanInfo(iCh).Chan <= 0 ) || ( Fatigue.ChanInfo(iCh).Chan > FileInfo.nChannels ) ) )
         beep;
         error( '  For fatigue channel #%d, the channel number must be between 1 and %d (inclusive).', iCh, FileInfo.nChannels );
      end % if

      if ( doFatigue && (Fatigue.ChanInfo(iCh).NSlopes <= 0 ) )
         beep;
         error( '  For fatigue channel #%d, the number of S/N slopes (NSlopes) must be greater than zero.', iCh );
      end % if   

      if (iCh == 1)
         allSlopes = Fatigue.ChanInfo(iCh).SNslopes;
      else
         allSlopes = [allSlopes Fatigue.ChanInfo(iCh).SNslopes];
      end
      
      if ( Fatigue.BinCycles )
         if ( strcmp(Fatigue.ChanInfo(iCh).BinFlag,'BN') )
            Fatigue.ChanInfo(iCh).nBins    = Fatigue.ChanInfo(iCh).BinVal;
         else
            Fatigue.ChanInfo(iCh).BinWidth = Fatigue.ChanInfo(iCh).BinVal;
         end
      end % if Fatigue.BinCycles
      
      if ( isfinite( str2double( Fatigue.ChanInfo(iCh).TypeLMF ) ) )
         Fatigue.ChanInfo(iCh).LMF     = str2double( Fatigue.ChanInfo(iCh).TypeLMF );
         Fatigue.ChanInfo(iCh).TypeLMF = 'value';                    
      end % if
      
      if ( doFatigue && ( Fatigue.ChanInfo(iCh).LUlt <= 0 ) )
         beep;
         error( '  For fatigue channel #%d, the ultimate load (LUlt) must be > 0.', iCh );
      end % if
      
   end % for iCh
   
   if ( Fatigue.nFatigueChannels > 0 )
      allSlopes           = unique(sort(allSlopes));
      Fatigue.allSNSlopes = allSlopes;
   else
      Fatigue.DoShortTerm = false;
      Fatigue.DoLife      = false;
   end

   
      % Set up the fatigue groups.  
      
   Fatigue.nTotalGroupChannels = 0;
   
   if ( Fatigue.nGroups > 0 )
      
      for iGroup=1:Fatigue.nGroups
         
         nGroupChannels              = length(Fatigue.Groups(iGroup).channelIndices);
         Fatigue.nTotalGroupChannels = Fatigue.nTotalGroupChannels + nGroupChannels;
         
         for jCh=1:nGroupChannels
            
            currentChannel = Fatigue.Groups(iGroup).channelIndices(jCh);
            
            if ( currentChannel > Fatigue.nFatigueChannels )
               beep
               error( '  DEL Group Channnel index must be between 1 and number of fatigue channels.  ' );
            end % if
            
            if (jCh == 1)
               allSlopes = Fatigue.ChanInfo(currentChannel).SNslopes;
            else
               allSlopes = [allSlopes Fatigue.ChanInfo(currentChannel).SNslopes];
            end
            
         end % for jCh
         
         
            % Determine all SN slopes for this group
            
         allSlopes                          = unique(sort(allSlopes));
         Fatigue.Groups(iGroup).allSNSlopes = allSlopes;
         slopeMap                           = zeros(1,max(allSlopes));
         slopeMap(allSlopes)                = 1:length(allSlopes);
         Fatigue.Groups(iGroup).SNSlopeMap  = slopeMap;
         
      end  % for iGroup
      
   elseif (Fatigue.nFatigueChannels > 0 )  % all fatigue channels are in a single group
      
      Fatigue.nGroups = 1;
      Fatigue.Groups(1).channelIndices(1:Fatigue.nFatigueChannels) = 1:Fatigue.nFatigueChannels;
      
      for iCh=1:Fatigue.nFatigueChannels
         if (iCh == 1)
            allSlopes = Fatigue.ChanInfo(iCh).SNslopes;
         else
            allSlopes = [allSlopes Fatigue.ChanInfo(iCh).SNslopes];
         end
      end
      
      allSlopes                     = unique(sort(allSlopes));
      Fatigue.Groups(1).allSNSlopes = allSlopes;
      Fatigue.Groups(1).name        = '';
    
   end % if ( Fatigue.nGroups > 0 )
   


end % function process_mlife_inputs()