function Fatigue = compute_no_goodman_fatigue(nFiles, Fatigue, DLCs, DLC_Occurrences, windChannelMeans)
%
% Compute the fatigue and DEL related results without using a Goodman correction
% 
% Syntax is:
%            Fatigue = compute_goodman_fatigue(nFiles, Fatigue, DLCs, DLC_Occurrences, windChannelMeans)
%
%
% Inputs:
%           nFiles              - Number of time-series
%           Fatigue             - Fatigue data structure, see mlife() 
%           DLCs                - DLC data structure, see mlife()
%           DLC_Occurences      - Array of number of occurrences of each event in the third DLC type
%           windChannelMeans    - The mean wind speed for each time-series
%
%

   nFatigueChannels = Fatigue.nFatigueChannels;
   
   DEL_Type = 3; % no Goodman correction
   
   
      % This is where the calculations take place!
      
   [aggEquivalentCycles, lifetimeEquivalentCycles, ChannelBasedResults, FileBasedResults] = compute_fatigue_per_DEL_type( DEL_Type, DLCs, DLC_Occurrences, nFatigueChannels, nFiles, windChannelMeans, Fatigue );   
  
   
   Fatigue.lifetimeEquivalentCycles                                          = lifetimeEquivalentCycles;
   
   if (Fatigue.DoAggregate)
      Fatigue.aggEquivalentCycles                                            = aggEquivalentCycles;
   end
   
   
      % Store the results into the appropriate data structures
      
   for iCh = 1:nFatigueChannels
      
      if (Fatigue.DoAggregate)
         
            Fatigue.Channel(iCh).aggDamage_NoGoodman                         = ChannelBasedResults(iCh).aggDamage;
            Fatigue.Channel(iCh).aggDamageRate_NoGoodman                     = ChannelBasedResults(iCh).aggDamageRate;
            Fatigue.Channel(iCh).aggDEL_NoGoodman                            = ChannelBasedResults(iCh).DEL;
            
            if ( Fatigue.BinCycles )
               Fatigue.Channel(iCh).aggBinnedCycleCounts_NoGoodman           = ChannelBasedResults(iCh).aggBinnedCycleCounts;
            end
            
      end % if Fatigue.DoAggregate
      
      if ( Fatigue.DoLife )
         
         Fatigue.Channel(iCh).lifetimeDamage_NoGoodman                       = ChannelBasedResults(iCh).lifetimeDamage;
         Fatigue.Channel(iCh).timeUntilFailure_NoGoodman                     = ChannelBasedResults(iCh).timeUntilFailure;
         Fatigue.Channel(iCh).lifetimeDEL_NoGoodman                          = ChannelBasedResults(iCh).lifetimeDEL;
         
      end
      
      if ( Fatigue.DoShortTerm )
         
         for iFile = 1:nFiles  
            
            if ( Fatigue.BinCycles )
               Fatigue.File(iFile).Channel(iCh).binnedCycleCounts_NoGoodman  = FileBasedResults(iFile,iCh).binnedCycleCounts; 
            end
            
            Fatigue.File(iFile).Channel(iCh).DamageRate_NoGoodman            = FileBasedResults(iFile,iCh).DamageRate;
            Fatigue.File(iFile).Channel(iCh).DEL_NoGoodman                   = FileBasedResults(iFile,iCh).DEL;    
            
         end % for iFile
         
      end    % if Fatigue.DoSimpDEL
      
   end % for iCh
   
end % function compute_no_goodman_fatigue