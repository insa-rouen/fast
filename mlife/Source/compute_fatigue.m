function Fatigue = compute_fatigue( FileInfo, Fatigue, windChannelMeans )
% Perform a fatigue-life anaylsis.
%
% For now, it does a rainflow analysis and calculates fatigue life that is weighted
% by a probability distribution as well as short-term and lifetime DELs
%
% Syntax is:  Fatigue = compute_fatigue( FileInfo, Fatigue, windChannelMeans );
%
% Example:
%     Fatigue = compute_fatigue( FileInfo, Fatigue, windChannelMeans );
%
% Called by: mlife
% Calls to:  bin_channel_load_ranges, RFPerUnits, compute_no_goodman_fatigue, 
%            compute_goodman_fatigue 
%


   fprintf( '\n  Performing fatigue-life analysis.\n' );

   nFatigueChannels = Fatigue.nFatigueChannels;
   nFiles           = FileInfo.nFiles;
   
   % Set the string for the Design Lifetime period.

   Fatigue.RFPerStr = RFPerUnits( Fatigue.DesignLife );
  
   
   % Initialize all results to zero in case of an error or not enough peaks
   % for fatigue analysis
 
   Fatigue.lifetimeEquivalentCycles  = 0.0;  
   
   for iFiles=1:nFiles
      
      for i=1:nFatigueChannels
         
         nSNSlopes = Fatigue.ChanInfo(i).NSlopes;
         
         for j=1:nSNSlopes
            Fatigue.File(iFiles).Channel(i).DEL_FixedMeans(j) = 0.0;
         end
         
      end
      
   end
   
   for i=1:nFatigueChannels
      
      nSNSlopes = Fatigue.ChanInfo(i).NSlopes;

      for j=1:nSNSlopes     
            Fatigue.Channel(i).lifetimeDamage(j) = 0.0;      
      end
      
   end
   
   if ( Fatigue.BinCycles ) 

         % Create the load range bins for each fatigue channel
     
     Fatigue.ChanInfo = bin_channel_load_ranges(nFiles, nFatigueChannels, Fatigue.ChanInfo, Fatigue.Peaks, Fatigue.GoodmanFlag, Fatigue.DEL_Type, Fatigue.UCMult, Fatigue.DoAggregate); 
     
   end
   
   switch Fatigue.GoodmanFlag
      
      case 0 % no Goodman Correction
         
         Fatigue = compute_no_goodman_fatigue(nFiles, Fatigue, FileInfo.DLCs, FileInfo.DLC_Occurrences, windChannelMeans); 
         
      case 1 % with Goodman Correction
         
         Fatigue = compute_goodman_fatigue(nFiles, Fatigue, FileInfo.DLCs, FileInfo.DLC_Occurrences, windChannelMeans);
         
      case 2 % both with and without
         
         Fatigue = compute_no_goodman_fatigue(nFiles, Fatigue, FileInfo.DLCs, FileInfo.DLC_Occurrences, windChannelMeans);
         Fatigue = compute_goodman_fatigue(nFiles, Fatigue, FileInfo.DLCs, FileInfo.DLC_Occurrences, windChannelMeans);
         
      otherwise
         
         error('Invalid Fatigue.GoodmanFlag value');
         
   end   % switch Fatigue.GoodmanFlag

   fprintf( '    Done calculating fatigue-life results.\n' );
   
   return
   
   %=======================================================================
   % Internal functions
   %=======================================================================



      % Create the load range bins for each fatigue channel
      
   function ChanInfo = bin_channel_load_ranges(nFiles, nFatigueChannels, ChanInfo, peaks, GoodmanFlag, DEL_Type, UCMult, doAggregate)
        maxCycles = get_max_cycle_ranges(nFiles, nFatigueChannels, peaks, GoodmanFlag, DEL_Type, UCMult, ChanInfo, doAggregate);
        for iCh=1:nFatigueChannels
           if ( strcmp(Fatigue.ChanInfo(iCh).BinFlag, 'BN') ) % # of bins was specified by user
               nLoadRangeBins                         = ChanInfo(iCh).nBins;
                loadRangeBinWidth = get_load_range_bins_by_number(maxCycles(iCh), nLoadRangeBins);  
               ChanInfo(iCh).BinWidth         = loadRangeBinWidth;
            else % bin width was specified by user
               loadRangeBinWidth                   = ChanInfo(iCh).BinWidth;
               nLoadRangeBins = get_load_range_bins_by_width(maxCycles(iCh), loadRangeBinWidth); 
               ChanInfo(iCh).nBins         = nLoadRangeBins;
           end
        end     % for iCh  
   end

   %=======================================================================

   function nBinsNeeded = get_load_range_bins_by_width(cycleMax, loadRangeBinWidth)
      
      nBinsNeeded = ceil( cycleMax/loadRangeBinWidth );
    
   end

   function loadRangeBinWidth = get_load_range_bins_by_number(cycleMax, nBins)
      % Assumption is that the max cycle mean should fall in the 
      % last bin
      loadRangeBinWidth =  cycleMax / nBins ;
        
      return;
   end

   %=======================================================================

   function RFPerStr = RFPerUnits( DesignLife )
      % Determine the units string for the rainflow period.
      
      
      if ( DesignLife == 1.0 )
         
         RFPerStr = 'Cycles per Second';
         
         %      elseif ( DesignLife < 60.0 )
         %
         %         RFPerStr = sprintf( 'Cycles per %g Seconds', DesignLife );
         %
      elseif ( mod( DesignLife, 31536000.0 ) == 0.0 )
         
         if ( DesignLife == 31536000.0 )
            RFPerStr = 'Cycles per Year';
         else
            RFPerStr = sprintf( 'Cycles per %g Years', DesignLife/31536000.0 );
         end % if
         
      elseif ( mod( DesignLife, 86400.0 ) == 0.0 )
         
         if ( DesignLife == 86400.0 )
            RFPerStr = 'Cycles per Day';
         else
            RFPerStr = sprintf( 'Cycles per %g Days', DesignLife/86400.0 );
         end % if
         
      elseif ( mod( DesignLife, 3600.0 ) == 0.0 )
         
         if ( DesignLife == 3600.0 )
            RFPerStr = 'Cycles per Hour';
         else
            RFPerStr = sprintf( 'Cycles per %g Hours', DesignLife/3600.0 );
         end % if
         
      elseif ( mod( DesignLife, 60.0 ) == 0.0 )
         
         if ( DesignLife == 60.0 )
            RFPerStr = 'Cycles per Minute';
         else
            RFPerStr = sprintf( 'Cycles per %g Minutes', DesignLife/60.0 );
         end % if
         
      else
         
         RFPerStr = sprintf( 'Cycles per %g Seconds', DesignLife );
         
      end % if
      
   end % function RFPerStr = RFPerUnits( DesignLife )

   %=======================================================================

end % compute_fatigue()
