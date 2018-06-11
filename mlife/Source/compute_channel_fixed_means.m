function Fatigue = compute_channel_fixed_means(Fatigue, FileInfo, channelMeans, windChannelMeans)
% Calculate the fixed mean load for the fatigue channels using one of two methods:
% 1) aggregate mean of all the input data 
% 2) the file-based means weighted by the wind speed distribution
% The results are stored back into the Fatigue structure in the LMF variable.
%
%
% Syntax is:  Fatigue = compute_channel_fixed_means(Fatigue, FileInfo, channelMeans, windChannelMeans)
%
%     where:
%        Fatigue           - 
%        FileInfo          - 
%        channelMeans      - 
%        windChannelMeans  - 
%       
% Example:
%     Fatigue = compute_channel_fixed_means(Fatigue, FileInfo, channelMeans, windChannelMeans)
%
%
%  Called by: mlife

   nFatigueChannels = Fatigue.nFatigueChannels;
   nFiles           = FileInfo.nFiles;
   for iCh=1:nFatigueChannels
      lmf       = 0.0;
      totalTime = 0.0;
      chan = Fatigue.ChanInfo(iCh).Chan;
      
      if (strcmp( Fatigue.ChanInfo(iCh).TypeLMF, 'AM' ) )
         
         % For now only calculate the aggregate mean using the power production DLC files
         % TODO:  See if we want to implement anything else GJH Mar 8, 2012
         
         for iFile=1:FileInfo.DLCs(1).NumFiles
            lmf       = lmf + channelMeans(iFile,chan)*Fatigue.ElapTime(iFile);
            totalTime = totalTime + Fatigue.ElapTime(iFile);
         end
         lmf                       = lmf/totalTime;
         Fatigue.ChanInfo(iCh).LMF = lmf;
         
      elseif (strcmp( Fatigue.ChanInfo(iCh).TypeLMF, 'WM' ) ) %NOTE: This could be in conflict with useWeibull option...

         % Compute the weighted mean using the availability, DLC group, Weibull distribution, and 
         % mean channel load and wind speed bin of each file.
         
         for iFile=1:nFiles
            if ( iFile <= FileInfo.DLCs(1).NumFiles + FileInfo.DLCs(2).NumFiles )
               
               % These files are part of power production or parked DLCs
               
               WSbin     = get_windspeed_bin( windChannelMeans(iFile), Fatigue.WSin, Fatigue.WSout, ...
                              Fatigue.nWSbins, Fatigue.WSbinWidths ); 

               if ( (WSbin <= ( Fatigue.nWSbins(1)+Fatigue.nWSbins(2) )) && (WSbin > Fatigue.nWSbins(1)) )

                  % power production or parked inside Vin to Vout range

                  if ( iFile <= FileInfo.DLCs(1).NumFiles )
                     % power production DLC
                     a = Fatigue.Availability;
                  else 
                     % parked DLC
                     a = 1 - Fatigue.Availability;
                  end
               else
                  % power production or idling outside of Vin and Vout
                  a = 1; 
               end  % if WSbin
               
               lmf       = lmf + channelMeans(iFile,chan)*Fatigue.ElapTime(iFile)*Fatigue.WSProb(WSbin)*a;   
               totalTime = totalTime + Fatigue.ElapTime(iFile)*Fatigue.WSProb(WSbin)*a;

            end   % if  iFile
         end      % for iFile

         lmf                       = lmf/totalTime;
         Fatigue.ChanInfo(iCh).LMF = lmf;
      end  % if 'AM' or 'WM'
   
   end     % for iCh

end