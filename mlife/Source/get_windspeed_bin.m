function iBin = get_windspeed_bin( V, Vin, Vout, nBins, binWidths )
% Obtain the bin number for a given wind speed value, V.
%
%  Inputs:
%     V         -  wind speed
%     Vin       - cut-in wind speed of the turbine
%     Vout      - cut-out wind speed of the turbine
%     nBins     - (1x3) number of bins in each of the three sub-regions:  0-Vin, Vin-Vout, Vout-Vmax
%     binWidths - (1x3) array of bin widths for each of the three sub-regions
%
%  Usage:
%           iBin = get_windspeed_bin( 18.34, 3, 25, [2 11 5], [1.5 2 2] );
%
   if ( V == 0 )
      iBin = 1;
   elseif ( V < Vin )
      iBin = ceil( V / binWidths(1) );
   elseif ( V < Vout )
      iBin = nBins(1) + ceil( (V-Vin) / binWidths(2) );
   else
      iBin = nBins(1) + nBins(2) + ceil( (V-Vout) / binWidths(3) );
   end
 
end