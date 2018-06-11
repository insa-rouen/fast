function cycles = generate_cycles( peaks, UCMult, LUlt, LMF )
      % Generate rainflow cycles.

      % Algorithm is based on:

      %     Ariduru, Seçil (2004).  "Fatigue Life Calculation by Rainflow Cycle Counting Method."
      %     M.S. Thesis.  Ankara, Turkey: Middle East Technical University.

      % 
      % This routine also gives the exact same answers as MCrunch.



      % Process the peaks and valleys.

      nPeaks      = size( peaks, 1 );
      rangeList   = zeros( nPeaks-1, 1 );
      startList   = zeros( nPeaks-1, 1 );
      endList     = zeros( nPeaks-1, 1 );
      nCycles     = 0;
      cycles      = zeros( int32( size( peaks, 1 )/2 - 0.5 ), 4 );
      LFMargin    = LUlt - abs(LMF);
      
      if ( nPeaks < 3 )
         % Not enough data to count, quit
         return;
      end
      
      % Create initial ranges to begin the rainflow process
      startList(1) = peaks(1);
      endList(1)   = peaks(2);
      rangeList(1) = abs(peaks(2) - peaks(1));
      rlInd        = 1;
      peakInd      = 2;
      
      
      while ( peakInd < nPeaks )

         
         % Add a new range
         rlInd             = rlInd + 1;
         startList(rlInd)  = peaks(peakInd);
         peakInd           = peakInd + 1;
         endList(rlInd)    = peaks(peakInd);
         rangeList(rlInd)  = abs( endList(rlInd) - startList(rlInd) );
         
         % If the new range is as large as the oldest active range, we found a cycle.
         % If rlInd is 2, it's a partial cycle.  Add it to the list of cycles.

         while ( rlInd > 1 && rangeList(rlInd) >= rangeList(rlInd-1) )

            nCycles = nCycles + 1;

            cycles(nCycles,1) = rangeList(rlInd-1);
            cycles(nCycles,2) = 0.5*( startList(rlInd-1) + endList(rlInd-1) );
            cycles(nCycles,3) = cycles(nCycles,1)*LFMargin/( LUlt - abs( cycles(nCycles,2) ) );

            if ( rlInd > 2 )
               cycles(nCycles,4) = 1.0;
               endList(rlInd-2)  = endList(rlInd);     
               rlInd             = rlInd - 2;
               rangeList(rlInd)  = abs(startList(rlInd) - endList(rlInd));
            else
               cycles(nCycles,4) = UCMult;
               rangeList(1)      = rangeList(2);
               startList(1)      = startList(2);
               endList(1)        = endList(2);
               rlInd             = 1;
            end % if ( LenUC > 3 )

         end % while ( rangeList(rlInd) >= rangeList(rlInd-1) )

         

      end % while


      % Add the unclosed cycles to the end of the cycles matrix if the weight is not zero.

      if ( ( rlInd > 1 ) && ( UCMult > 0 ) )

         for iRange=1:rlInd
            cycles(nCycles+iRange,1) = rangeList(iRange);
            cycles(nCycles+iRange,2) = 0.5*( startList(iRange) + endList(iRange) );
            cycles(nCycles+iRange,3) = cycles(nCycles+iRange,1)*LFMargin/( LUlt - abs( cycles(nCycles+iRange,2) ) );
            cycles(nCycles+iRange,4) = UCMult;
         end % for Cyc

      else

         rlInd = 0;

      end % if ( ( LenUC > 1 ) && ( UCMult > 0 ) )


      % Truncate the unused portion of the array.

      totCycles = nCycles + rlInd ;
      cycles    = cycles(1:totCycles,:);
            
   end % function cycles = generate_cycles( Peaks, UCMult, LUlt, LMF )