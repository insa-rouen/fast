function Fatigue = compute_windspeed_bins(Fatigue, windChannelMeans, nDLC1Files, nDLC2Files)  

% Compute windspeed bins based on the selected Weibull distribution, and
% the elasped time for each windspeed bin
%
%  Called by: mlife


   
   
   
   % Compute necessary quantities based on what the user input
   k = Fatigue.weibullShapeFactor;
   if ( k == 2 )
      % user entered mean ws.  Need to calculate scale factor and std of wind          
      Fatigue.weibullScaleFactor = Fatigue.weibullMeanWS / gamma(1 + 1/k);
      Fatigue.weibullStdDev      = sqrt(Fatigue.weibullMeanWS^2*(gamma(1+(2./k))/((gamma(1+(1/k)))^2) - 1));
   else
      % user entered scale factor, need to calculate mean ws and std of wind
      Fatigue.weibullMeanWS = Fatigue.weibullScaleFactor*gamma(1 + 1/k);
      Fatigue.weibullStdDev = sqrt(Fatigue.weibullMeanWS^2*(gamma(1+(2./k))/((gamma(1+(1/k)))^2) - 1));
   end 
   
   c = Fatigue.weibullScaleFactor;

   % Determine the number of wind speed bins to use.
   % Currently the user inputs WSin and WSout and WSmax and the WSMaxBinSize in the settings file.
  
   % Wind speed bins are split into three distinct ranges,  0 - WSin , WSin - WSout , WSout - WSmax
   
   % Compute the first set of bins:  0 < V < Vin
   [nBins1, binWidth1, binProbabilites1] = compute_bins(0, Fatigue.WSin, Fatigue.WSMaxBinSize);
   
   
   % Compute the second set of bins:  Vin < V < Vout
   [nBins2, binWidth2, binProbabilites2] = compute_bins(Fatigue.WSin, Fatigue.WSout, Fatigue.WSMaxBinSize);
   
   
   % Compute the third set of bins:  Vout < V < Vmax
   [nBins3, binWidth3, binProbabilites3] = compute_bins(Fatigue.WSout, Fatigue.WSmax, Fatigue.WSMaxBinSize);
   
   
   Fatigue.nWSbins = [nBins1  nBins2  nBins3];
   Fatigue.WSProb = [binProbabilites1; binProbabilites2; binProbabilites3];
   Fatigue.WSbinWidths = [binWidth1 binWidth2 binWidth3];
   
 
      % Compute the total time in each wind-speed bin.

   Fatigue.Time = zeros( sum(Fatigue.nWSbins), 2 );

   % We should only accumulate time for the power production and idling DLC files, not the discrete event files!!
   for iFile=1:nDLC1Files
      WSbin                  = get_windspeed_bin(windChannelMeans(iFile),Fatigue.WSin, Fatigue.WSout, Fatigue.nWSbins, Fatigue.WSbinWidths);
      Fatigue.Time(WSbin,1)    = Fatigue.Time(WSbin,1) + Fatigue.ElapTime(iFile);
   end
   % Time is accumulated separately for power production and idling
   for iFile=1:nDLC2Files
      WSbin                  = get_windspeed_bin(windChannelMeans(iFile+nDLC1Files),Fatigue.WSin, Fatigue.WSout, Fatigue.nWSbins, Fatigue.WSbinWidths);
      Fatigue.Time(WSbin,2)    = Fatigue.Time(WSbin,2) + Fatigue.ElapTime(iFile+nDLC1Files);
   end
   return
   
   function [ nBins, binWidth, bins ] = compute_bins(Vmin, Vmax, maxBinSize)
      nBins   =  ceil( (Vmax - Vmin) / maxBinSize );
      bins = zeros(nBins,1);
      binWidth = ( (Vmax - Vmin) / nBins ) ;
      for iBin=1:nBins
         WShi                = Vmin + iBin*binWidth;
         WSlo                = WShi - binWidth;
         if (Fatigue.useWeibull)
               % The probability for each wind-speed bin is found using the Weibull distribution CDF.
            bins(iBin) = wblcdf(WShi, c, k) - wblcdf(WSlo, c, k) ;  
         else
            bins(iBin) = 1;
         end
      end % for iBin
   end % compute_bins
end
   