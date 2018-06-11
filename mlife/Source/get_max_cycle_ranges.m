function cycleMaxima = get_max_cycle_ranges(nFiles, nFatigueChannels, allPeaks, GoodmanFlag, DEL_Type, UCMult, ChanInfo, doAggregate)
      % Generate rainflow cycles.
   cycleMaxima = zeros(nFatigueChannels,1);
   
   % Determine which load range type we need to be using to compute the maximum load ranges
   
   switch GoodmanFlag
      case 0
         cycleType = 1; % raw cycles
      case 1
         switch DEL_Type
            case 1
               cycleType = 3; % fixed mean
            case 2
               cycleType = 5; % zero mean
            case 3
               cycleType = 5; % zero mean is conservative if both fixed and zero are being calculated
         end
      case 2
         cycleType = 5; %conservative???
   end
   
%    if ( doAggregate )
%        for iCh = 1:nFatigueChannels
%                
%          peaks = allPeaks{1}{iCh};
%          for i=2:nFiles
%             peaks = [peaks ; allPeaks{i}{iCh}];
%          end
%          cycles = rainflow(peaks, abs( double(ChanInfo(iCh).LMF)), double(ChanInfo(iCh).LUlt), double(UCMult) )';
%          cycleRanges = cycles(:,cycleType);
% %          switch DEL_Type
% %             case 0   % computing all DEL types
% %                cycleRanges = cycles(:,5);
% %             case 1  % fixed mean
% %                cycleRanges = cycles(:,3);
% %             case 2  % zero-mean
% %                cycleRanges = cycles(:,5);
% %             case 3  % variable means
% %                cycleRanges = cycles(:,1);
% %             otherwise 
% %                % error
% %           
% %          end
% %          
%          cycleMaxima(iCh) = max(cycleRanges);
%          
%        end  % for iCh
%         
%    end

   for iFile = 1:nFiles  % loop over the input files
      for iCh = 1:nFatigueChannels
         
         peaks = allPeaks{iFile}{iCh};
%          cycles = rainflow(peaks, abs( double(ChanInfo(iCh).LMF)), double(ChanInfo(iCh).LUlt), double(UCMult) )';
%          maxCycles = max(cycles);
%          if (maxCycles(1) > cycleMaxima(iCh,1) )
%             cycleMaxima(iCh,1) = maxCycles(1);
%          end
%          if (maxCycles(3) > cycleMaxima(iCh,2) )
%             cycleMaxima(iCh,2) = maxCycles(3);
%          end
         
         cycles = rainflow(double(peaks), abs( double(ChanInfo(iCh).LMF)), double(ChanInfo(iCh).LUlt), double(UCMult) )';
         cycleRanges = cycles(:,cycleType);
%          switch DEL_Type
%             case 0   % computing all DEL types
%                cycleRanges = cycles(:,5);
%             case 1  % fixed mean
%                cycleRanges = cycles(:,3);
%             case 2  % zero-mean
%                cycleRanges = cycles(:,5);
%             case 3  % variable means
%                cycleRanges = cycles(:,1);
%             otherwise 
%                % error
%           
%          end
         maxCycles = max(cycleRanges);
         
         if (maxCycles > cycleMaxima(iCh) )
            cycleMaxima(iCh) = maxCycles;
         end
         
      end % for iCh
   end    % for iFile
   
   end % function cycles = generate_all_cycles( allPeaks, UCMult, ChanInfo )