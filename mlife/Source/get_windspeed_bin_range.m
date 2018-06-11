function [low, high] = get_windspeed_bin_range( iBin, Vin, Vout, Vmax, nBins, binWidths )

   if ( iBin <= nBins(1) )
      Vmin     = 0;
      Vmax     = Vin;
      del      = binWidths(1);
      localBin = iBin - 1;
   elseif ( iBin <= ( nBins(1)+nBins(2) ) )
      Vmin     = Vin;
      Vmax     = Vout;
      del      = binWidths(2);
      localBin = iBin - nBins(1) - 1;
   else
      Vmin     = Vout;
      Vmax     = Vmax;
      del      = binWidths(3);
      localBin = iBin - ( nBins(1) + nBins(2) ) - 1 ;
   end
   
   low  = Vmin + localBin*del;
   high = low  + del;
end