function [aggEquivalentCycles, lifetimeEquivalentCycles, ChannelBasedResults, FileBasedResults] = compute_fatigue_per_DEL_type( DEL_Type, DLCs, DLC_Occurrences, nFatigueChannels, nFiles, windChannelMeans, Fatigue )
%
% This function calculates all fatigue and DEL related results for a specified DEL type (see below). 
%
% Syntax is:  [aggEquivalentCycles, lifetimeEquivalentCycles, ChannelBasedResults, FileBasedResults] = 
%                 compute_fatigue_per_DEL_type( DEL_Type, DLCs, DLC_Occurrences, nFatigueChannels, nFiles, windChannelMeans, Fatigue )
%
% Inputs:
%      
%      DEL_Type                                -  What type of DEL is being computed?  1 = with Goodman correction about a fixed mean,
%                                                   2 = with Goodman correction about a zero mean, 3 = no Goodman correction about a zero mean
%      DLCs                                    -  DLC data structure, see mlife()
%      DLC_Occurrences                         -  Array of number of occurrences of each event in the third DLC type
%      nFatigueChannels                        -  Number of fatigue channels
%      nFiles                                  -  Number of time-series
%      windChannelMeans                        -  The mean wind speed for each time-series
%      Fatigue                                 -  Fatigue data structure, see mlife()
%
% Outputs: 
%        
%      lifetimeEquivalentCycles                -  Equivalent number of damage cycles over the design lifetime
%      ChannelBasedResults.lifetimeDamage      -  Lifetime damage for each fatigue channel
%      ChannelBasedResults.timeUntilFailure    -  Time until failure for each fatigue channel
%      ChannelBasedResults.lifetimeDEL         -  The lifetime-based DEL for each fatigue channel
%      FileBasedResults.binnedCycleCounts      -  binned damage counts for each time-series and channel
%      FileBasedResults.DamageRate             -  The short-term damage-rate for each time-series and channel and S/N slope value
%      FileBasedResults.DEL                    -  The short-term DEL for each time-series,each channel, and each S/N slope value 
%
%
  
  
      % Initialize data
  
   aggEquivalentCycles       = 0;
   lifetimeEquivalentCycles  = 0;
   Channels                  = repmat( struct( 'lifetimeCycleRanges',0) , 1, nFatigueChannels );
   ChannelBasedResults       = repmat( struct( 'aggBinnedCycleCounts',0, 'lifetimeDamage',0,'timeUntilFailure',0,'lifetimeDEL',0) , 1, nFatigueChannels );
   FileBasedResults          = repmat( struct( 'binnedCycleCounts',0,'DamageRate',0,'DEL',0) , nFiles, nFatigueChannels );
   
   for iCh=1:nFatigueChannels
         nSNSlopes = Fatigue.ChanInfo(iCh).NSlopes;
         
            % lifetime results
         ChannelBasedResults(iCh).lifetimeDamage         = zeros(1,nSNSlopes);
         ChannelBasedResults(iCh).timeUntilFailure       = zeros(1,nSNSlopes);
         ChannelBasedResults(iCh).lifetimeDEL            = zeros(1,nSNSlopes);
   
            % aggregate results
         ChannelBasedResults(iCh).DEL                    = zeros(1,nSNSlopes);
         ChannelBasedResults(iCh).aggDamageRate          = zeros(1,nSNSlopes);
         ChannelBasedResults(iCh).aggDamage              = zeros(1,nSNSlopes);
         ChannelBasedResults(iCh).aggBinnedCycleCounts   = 0;  % this will end up being multiple arrays of varying lengths
         
            % temporary storage
         Channels(iCh).lifetimeCycleRanges               = zeros(1,nSNSlopes);
         Channels(iCh).aggCycleRanges                    = zeros(1,nSNSlopes);
         
         for iFile=1:nFiles           
               % short-term results
            FileBasedResults(iFile,iCh).DamageRate        = zeros(1,nSNSlopes);
            FileBasedResults(iFile,iCh).DEL               = zeros(1,nSNSlopes);
            FileBasedResults(iFile,iCh).binnedCycleCounts = 0;  % this will end up being multiple arrays of varying lengths
           
         end
        
   end
   
   
      % This is the primary loop for accumulating damage over all the time-series
      
   for iFile = 1:nFiles  
        
      nEquivalantCounts = Fatigue.ElapTime(iFile)*Fatigue.EquivalentFrequency ; 

      
         % Determine the timeFactor used to extrapolate the time-series data across the design lifetime. 
      
      if ( iFile <= DLCs(1).NumFiles + DLCs(2).NumFiles )
         
         if ( iFile <= DLCs(1).NumFiles )
            iDLC = 1;
         else
            iDLC = 2;
         end
         
         timeFactor = extrapolate_time_factor( iDLC, windChannelMeans(iFile), Fatigue.WSin, Fatigue.WSout, ...
                                               Fatigue.nWSbins, Fatigue.WSbinWidths, Fatigue.DesignLife, ...
                                               Fatigue.Time, Fatigue.WSProb, Fatigue.Availability );
         
      else
         
            % For discrete events, do not extrapolate the time factor, simply count the event
            
         timeFactor = double( DLC_Occurrences( iFile - ( DLCs(1).NumFiles + DLCs(2).NumFiles ) ) );
         
      end

      for iCh = 1:nFatigueChannels

         peaks = Fatigue.Peaks{iFile}{iCh};
 
         if ( size(peaks,1) > 2 ) % make sure there are at least 3 peaks per time series
                            
            if ( DEL_Type == 1 ) %  Goodman with fixed mean correction
               lmf = Fatigue.ChanInfo(iCh).LMF;
            else
               lmf = 0.0;
            end
                   
               % Rainflow count the cycles using a mex function.  
               % For comparison, you could also using the Matlab function generate_cycles()
               
            cycles = rainflow(double(peaks), abs( double(lmf)), double(Fatigue.ChanInfo(iCh).LUlt), double(Fatigue.UCMult))';
          % cycles = generate_cycles( peaks, Fatigue.UCMult, double(Fatigue.ChanInfo(iCh).LUlt), double(lmf) );
           
            switch DEL_Type
               case 1  % Goodman correction with a specified fixed mean
                  cycleRanges = cycles(:,3);
               case 2  % Goodman correction with a fixed zero mean
                  cycleRanges = cycles(:,3); % was 5
               case 3  % no Goodman correction
                  cycleRanges = cycles(:,1);
               otherwise 
                  % error
          
            end
            
            cycleCounts = cycles(:,4);
            cycles = 0; % free memory
            
       
            if ( Fatigue.BinCycles )
               
               nLoadRangeBins = Fatigue.ChanInfo(iCh).nBins ;
               loadRangeBinWidth =  Fatigue.ChanInfo(iCh).BinWidth;
               binnedCycleCounts =  zeros( nLoadRangeBins, 1 );
               
               for c=1:length( cycleRanges )
                  index                    = ceil( cycleRanges(c)/loadRangeBinWidth );
                  binnedCycleCounts(index) = binnedCycleCounts(index) + cycleCounts(c);
               end % for c
               
               if (Fatigue.DoAggregate)
                  
                  if (iFile == 1)
                     ChannelBasedResults(iCh).aggBinnedCycleCounts = binnedCycleCounts;
                  else
                     ChannelBasedResults(iCh).aggBinnedCycleCounts = ChannelBasedResults(iCh).aggBinnedCycleCounts + binnedCycleCounts;    % OUTPUT %
                  end
                  
               end
               
               FileBasedResults(iFile,iCh).binnedCycleCounts       = binnedCycleCounts;    % OUTPUT %
               
                        
                  % Array of load range bin values (middle of bin)

               binMean = ((1:nLoadRangeBins)' - 0.5).*loadRangeBinWidth;

               
                  % Eliminate bins with 0 Counts.  The problem with load ranges which have 0 cycle counts, is that
                  % it generates a divide by zero in the equations below.
               
               nonZeroBins       = binnedCycleCounts > 0;
               binnedCycleCounts = binnedCycleCounts(nonZeroBins);
               binMean           = binMean(nonZeroBins);

               
                  % extrapolate the cycles across the lifetime.                 
               lifetimeCycles    = binnedCycleCounts.*timeFactor;
                 
               
            else   % unbinned cycles
            
                  % extrapolate the cycles across the lifetime.
               lifetimeCycles    = cycleCounts.*timeFactor;
            
            end    % if ( Fatigue.BinCycles )
            
            
            for iSlope = 1:Fatigue.ChanInfo(iCh).NSlopes
               
               SNslope = Fatigue.ChanInfo(iCh).SNslopes(iSlope);
 
               if ( Fatigue.BinCycles )    
                  
                  
                     % Compute cycles to failure per Equation 52 of the Theory manual.
               
                  cyclesToFailure = ( ( Fatigue.ChanInfo(iCh).LUlt - abs( double(lmf) ))./( 0.5*binMean )).^SNslope;  
                   
                  if (Fatigue.DoAggregate)
                     aggCycleRanges = sum(binnedCycleCounts.*(binMean.^SNslope)); 
                  end
                    
                     % should be using binnedCycleCountsRO instead of binnedCycleCounts for the lifetimeCycles!!!
                  lifetimeCycleRanges = sum(binnedCycleCounts.*timeFactor.*(binMean.^SNslope)); 
               
                  del   = ( sum( binnedCycleCounts.*( binMean.^SNslope ) )./double(nEquivalantCounts) )^( 1/SNslope );

                  FileBasedResults(iFile,iCh).DEL(iSlope) = del;  % OUTPUT % 
                   
                  damage     = sum(binnedCycleCounts./cyclesToFailure);
                  
                  if (Fatigue.DoAggregate)
                     % Compute aggDamage, and aggDamageRate based on the
                     % GJH: The following has the undesired side-effect of creating a NaN result if one time-series has a zero timeFactor (e.g. Availability = 1 or 0)
                     %damage     = sum(lifetimeCycles./timeFactor./cyclesToFailure);
                     
                     ChannelBasedResults(iCh).aggDamage(iSlope) = ChannelBasedResults(iCh).aggDamage(iSlope) + damage;          % OUTPUT %
                     if ( iFile == nFiles ) 
                       
                        ChannelBasedResults(iCh).aggDamageRate(iSlope) = ChannelBasedResults(iCh).aggDamage(iSlope) / sum(Fatigue.ElapTime(:));                            % OUTPUT %
                     end
                  end % if DoAggregate
                  
                  FileBasedResults(iFile,iCh).DamageRate(iSlope)  = damage / Fatigue.ElapTime(iFile);             % OUTPUT %
                  
               else  % unbinned calculations    NOTE: still using windspeed bins.  Should we?
                
                  
                     % Compute cycles to failure per Equation 6 of the Theory manual.
                     
                  cyclesToFailure  = ( ( Fatigue.ChanInfo(iCh).LUlt - abs( double(lmf) ) )./( 0.5*cycleRanges ) ).^SNslope;                  
                 
                  if (Fatigue.DoAggregate)
                        
                     % GJH: The following has the undesired side-effect of creating a NaN result if one time-series has a zero timeFactor (e.g. Availability = 1 or 0)
                        %aggCycleRanges = sum(lifetimeCycles./timeFactor.*(cycleRanges.^SNslope));
                     aggCycleRanges = sum(cycleCounts.*(cycleRanges.^SNslope));
                  end
                  
                  lifetimeCycleRanges = sum(lifetimeCycles.*(cycleRanges.^SNslope));       
                    
                  del   = ( sum( cycleCounts.*( cycleRanges.^SNslope ) )./double(nEquivalantCounts) )^( 1/SNslope );  

                  FileBasedResults(iFile,iCh).DEL(iSlope) = del;  % OUTPUT % 

                  damage     = sum(cycleCounts./cyclesToFailure);
                  
                  if (Fatigue.DoAggregate)
                     
                        % Compute aggDamage, and aggDamageRate based only on the time-series counts, no extrapolation.
                                          
                     ChannelBasedResults(iCh).aggDamage(iSlope) = ChannelBasedResults(iCh).aggDamage(iSlope) + damage;          % OUTPUT %
                     
                     if ( iFile == nFiles )                      
                        ChannelBasedResults(iCh).aggDamageRate(iSlope) = ChannelBasedResults(iCh).aggDamage(iSlope) / sum(Fatigue.ElapTime(:));                            % OUTPUT %
                     end
                     
                  end % if DoAggregate
                  
                     % This is the file-based damage rate
                  FileBasedResults(iFile,iCh).DamageRate(iSlope) = damage / Fatigue.ElapTime(iFile);             % OUTPUT %
                        
               end % if (Fatigue.BinCycles )
               
           
               if (Fatigue.DoAggregate)
                  Channels(iCh).aggCycleRanges(iSlope) = Channels(iCh).aggCycleRanges(iSlope) + aggCycleRanges;
               end % if DoAggregate
               
               Channels(iCh).lifetimeCycleRanges(iSlope) = Channels(iCh).lifetimeCycleRanges(iSlope) + lifetimeCycleRanges;
                  
                  % This is the extrapolated damage across the design lifetime.
               damage     = sum(lifetimeCycles./cyclesToFailure);
               
               ChannelBasedResults(iCh).lifetimeDamage(iSlope) = ChannelBasedResults(iCh).lifetimeDamage(iSlope) + damage;  % OUTPUT %
               
                              
            end % for iSlope
            
         end % if npeaks > 3
         
      end % for iCh
      
      if ( Fatigue.DoAggregate )
         aggEquivalentCycles = aggEquivalentCycles + nEquivalantCounts;
      end
               
      lifetimeEquivalentCycles = lifetimeEquivalentCycles + nEquivalantCounts*timeFactor;                                      % OUTPUT %
       
      
   end % for iFile

   
      % Compute Lifetime Damage Equivalent Loads and time until failure
   
    for iCh = 1:nFatigueChannels
       for iSlope = 1:Fatigue.ChanInfo(iCh).NSlopes;
          
         SNslope = Fatigue.ChanInfo(iCh).SNslopes(iSlope);
         
            % Compute aggregate DEL
         if (Fatigue.DoAggregate)
            ChannelBasedResults(iCh).DEL(iSlope) = ( Channels(iCh).aggCycleRanges(iSlope) / double(aggEquivalentCycles) )^(1/SNslope);   % OUTPUT %
         end

         ChannelBasedResults(iCh).timeUntilFailure(iSlope)      = Fatigue.DesignLife / ChannelBasedResults(iCh).lifetimeDamage(iSlope);  % OUTPUT %

         ChannelBasedResults(iCh).lifetimeDEL(iSlope) = ( Channels(iCh).lifetimeCycleRanges(iSlope) / double(lifetimeEquivalentCycles) )^(1/SNslope);  % OUTPUT %

       end % for iSlope

    end    % for iCh

   return 

end    % compute_fatigue_per_DEL_type()