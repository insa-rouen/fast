function Fatigue = compute_goodman_fatigue(nFiles, Fatigue, DLCs, DLC_Occurrences, windChannelMeans)
%
% Compute the fatigue and DEL related results for any DEL type which includes using a Goodman correction
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

      % perform all calculations  using the Goodman correction to the Load Ranges
   
   switch Fatigue.DEL_Type 
      
      case 1
      
         DEL_Type = 1; %  Goodman correction to a fixed mean
         [aggEquivalentCycles, lifetimeEquivalentCycles, ChannelBasedResultsF, FileBasedResultsF] = compute_fatigue_per_DEL_type( DEL_Type,  DLCs, DLC_Occurrences, nFatigueChannels, nFiles, windChannelMeans, Fatigue );
      
      case 2
      
         DEL_Type = 2; %  Goodman correction to a zero mean
         [aggEquivalentCycles, lifetimeEquivalentCycles, ChannelBasedResultsZ, FileBasedResultsZ] = compute_fatigue_per_DEL_type( DEL_Type,  DLCs, DLC_Occurrences, nFatigueChannels, nFiles, windChannelMeans, Fatigue );
      
      case 3
         
         DEL_Type = 1; %  Goodman correction to a fixed mean
         [aggEquivalentCycles, ~, ChannelBasedResultsF, FileBasedResultsF] = compute_fatigue_per_DEL_type( DEL_Type,  DLCs, DLC_Occurrences, nFatigueChannels, nFiles, windChannelMeans, Fatigue );
         DEL_Type = 2; %  Goodman correction to a zero mean
         [~, lifetimeEquivalentCycles, ChannelBasedResultsZ, FileBasedResultsZ]                   = compute_fatigue_per_DEL_type( DEL_Type,  DLCs, DLC_Occurrences, nFatigueChannels, nFiles, windChannelMeans, Fatigue );
      
      otherwise
         
   end  % switch Fatigue.DEL_Type
   
   
   Fatigue.lifetimeEquivalentCycles                                 = lifetimeEquivalentCycles;
   
   if (Fatigue.DoAggregate)
      Fatigue.aggEquivalentCycles                         = aggEquivalentCycles;
   end
   
   for iCh = 1:nFatigueChannels
      
      
         % save aggregate results into appropriate output data structures
         
      if (Fatigue.DoAggregate)       
         
         if (Fatigue.DEL_Type == 1 || Fatigue.DEL_Type == 3)
            
            Fatigue.Channel(iCh).aggDamage                       = ChannelBasedResultsF(iCh).aggDamage;
            Fatigue.Channel(iCh).aggDamageRate                   = ChannelBasedResultsF(iCh).aggDamageRate;
            Fatigue.Channel(iCh).aggDEL_FixedMeans               = ChannelBasedResultsF(iCh).DEL;
            
            if ( Fatigue.BinCycles )
               Fatigue.Channel(iCh).aggBinnedCycleCounts_FixedMeans = ChannelBasedResultsF(iCh).aggBinnedCycleCounts;   
            end
            
         end     % if (Fatigue.DEL_Type ...)
         
         if (Fatigue.DEL_Type == 2 || Fatigue.DEL_Type == 3)
            
            Fatigue.Channel(iCh).aggDamage                       = ChannelBasedResultsZ(iCh).aggDamage;
            Fatigue.Channel(iCh).aggDamageRate                   = ChannelBasedResultsZ(iCh).aggDamageRate;
            Fatigue.Channel(iCh).aggDEL_ZeroMeans               = ChannelBasedResultsZ(iCh).DEL;
            
            if ( Fatigue.BinCycles )
               Fatigue.Channel(iCh).aggBinnedCycleCounts_ZeroMeans = ChannelBasedResultsZ(iCh).aggBinnedCycleCounts;   
            end
            
         end  % if (Fatigue.DEL_Type ...)
         
      end    % if Fatigue.DoAggregate
      
      
         % save lifetime results into appropriate output data structures
         
      if ( Fatigue.DoLife )
         
         if (Fatigue.DEL_Type == 1 || Fatigue.DEL_Type == 3)
            
            Fatigue.Channel(iCh).lifetimeDamage                    = ChannelBasedResultsF(iCh).lifetimeDamage;
            Fatigue.Channel(iCh).timeUntilFailure                  = ChannelBasedResultsF(iCh).timeUntilFailure;
            Fatigue.Channel(iCh).lifetimeDEL_FixedMeans                       = ChannelBasedResultsF(iCh).lifetimeDEL;
            
         end % if (Fatigue.DEL_Type ...)
         
         if (Fatigue.DEL_Type == 2 || Fatigue.DEL_Type == 3)
            
            if (Fatigue.DEL_Type == 2)
               
               Fatigue.Channel(iCh).lifetimeDamage                    = ChannelBasedResultsZ(iCh).lifetimeDamage;
               Fatigue.Channel(iCh).timeUntilFailure                  = ChannelBasedResultsZ(iCh).timeUntilFailure;
               
            end % if (Fatigue.DEL_Type == 2)
            
            Fatigue.Channel(iCh).lifetimeDEL_ZeroMeans                       = ChannelBasedResultsZ(iCh).lifetimeDEL;
            
         end % if (Fatigue.DEL_Type ...)
         
      end  % if Fatigue.DoLife
      
      
         % save short-term results into appropriate output data structures
         
      for iFile = 1:nFiles  
         
         if ( Fatigue.DoShortTerm )  
            
            if (Fatigue.DEL_Type == 1 || Fatigue.DEL_Type == 3)
               
               Fatigue.File(iFile).Channel(iCh).DamageRate                       = FileBasedResultsF(iFile,iCh).DamageRate;
               
               if ( Fatigue.BinCycles )
                  Fatigue.File(iFile).Channel(iCh).binnedCycleCounts_FixedMeans     = FileBasedResultsF(iFile,iCh).binnedCycleCounts; 
               end
               
               Fatigue.File(iFile).Channel(iCh).DEL_FixedMeans                   = FileBasedResultsF(iFile,iCh).DEL;
               
            end % if (Fatigue.DEL_Type ...)
            
            if (Fatigue.DEL_Type == 2 || Fatigue.DEL_Type == 3)
               
               if (Fatigue.DEL_Type == 2)                  
                  Fatigue.File(iFile).Channel(iCh).DamageRate                       = FileBasedResultsZ(iFile,iCh).DamageRate;                  
               end
               
               if ( Fatigue.BinCycles )
                  Fatigue.File(iFile).Channel(iCh).binnedCycleCounts_ZeroMeans     = FileBasedResultsZ(iFile,iCh).binnedCycleCounts; 
               end
               
               Fatigue.File(iFile).Channel(iCh).DEL_ZeroMeans                   = FileBasedResultsZ(iFile,iCh).DEL;
               
            end % if (Fatigue.DEL_Type ...)
            
         end % if Fatigue.DoShortTerm
         
      end % for iFile
      
   end % for iCh
   
end % function compute_goodman_fatigue