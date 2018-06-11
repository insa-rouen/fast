
%===============================================================================
   function [Statistics] = compute_statistics( i, data, Statistics, n, doAggregate )
% Generate statistics of data.
%
% This function calculates the following statistics for data
% stored in the FileInfo data structure:
%     Minimum plus corresponding index
%     Mean
%     Maximum plus corresponding index
%     Standard Deviation
%     Skewness
%     Kurtosis
%     Range (Maximum-Minimum)
%
% It processes one dataset at a time and adds the computed statistics
% to the original Statistics data structure.  In order to generate aggregate
% statistics of all datafiles, intermediate quantities are computed which
% can in turn be used to calculate the aggregate statistics after all data
% files have been processed.  See compute_aggregate_statistics for more
% information.
%
% Syntax is:  compute_statistics( i, data, Statistics, fileName, n, doAggregate )
%
%     where:
%       i           -  index of input file which is having its statistics calculated.
%       data        - the channel data for the ith file
%       Statistics  - statistics structure
%       n           - number of datapoints in the input file
%       doAggregate - whether or not to compute additional terms needed for aggregate statistics
%
% Example:
%     compute_statistics(i, data, Statistics,  nLines,  true)
%    
% Called by: mlife


      
         % Individual-file statistics.
      RowRange = 1:n; %Check this GJH 24-May-2011      
      
  
      [Statistics.Minima(i,:), Statistics.MinInds(i,:)] = min(data(RowRange,:));
      [Statistics.Maxima(i,:), Statistics.MaxInds(i,:)] = max(data(RowRange,:));
     
      Statistics.Range(i,:)       = Statistics.Maxima(i,:) - Statistics.Minima(i,:);
      
      constChannels =(abs(Statistics.Range(i,:)) < realmin('single'));
      variableChannels = ~constChannels;
      Statistics.Means(i,constChannels)       = Statistics.Minima(i,constChannels);
      Statistics.StdDevs(i,constChannels)     = 0.0;
      Statistics.Skews(i,constChannels)       = 0.0;     
      
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   NOTE: The following block can be used to verify the home-grown statistics calculations
%       Statistics.Means(i,variableChannels)       = mean    ( data(RowRange,variableChannels) );
%       matLabSTD     = std     ( data(RowRange,variableChannels) );
%       matLabSKEW       = skewness( data(RowRange,variableChannels) );
%       matLabKURTOSIS    = kurtosis( data(RowRange,variableChannels) );

%       Statistics.Means(i,variableChannels)       = mean    ( data(RowRange,variableChannels) );
%       Statistics.StdDevs(i,variableChannels)     = std     ( data(RowRange,variableChannels) );
%       Statistics.Skews(i,variableChannels)       = skewness( data(RowRange,variableChannels) );
%       Statistics.Kurtosis(i,variableChannels)    = kurtosis( data(RowRange,variableChannels) );
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      

      
         % Need to cast data to double in order to have accurate stats calcs
         % using the polynomial expansion approach which is implemented below
         
      ddata         = double(data);
      sums          = sum(ddata(RowRange,variableChannels));
      sumsSquared   = sum(ddata(RowRange,variableChannels).^2);
      sumsCubed     = sum(ddata(RowRange,variableChannels).^3);
      sumsToFourth  = sum(ddata(RowRange,variableChannels).^4);
      
      means         = sums./ n;
      
      Statistics.Means(i,variableChannels) = means; 
      
      secondMoments = sumsSquared - (2*means.*sums) + n*means.^2;
      thirdMoments  = sumsCubed -(3*means.*sumsSquared) + (3*(means.^2).*sums)-n*means.^3;
      fourthMoments = sumsToFourth -(4*sumsCubed.*means) + (6*sumsSquared.*(means.^2)) -(4*sums.*(means.^3)) + n*means.^4;
      tempOne       = secondMoments ./ (n);
      
      Statistics.StdDevs(i,variableChannels)  = sqrt(secondMoments ./ (n-1));
      Statistics.Skews(i,variableChannels)    = (thirdMoments ./ n) ./ (sqrt(tempOne).^3);
      Statistics.Kurtosis(i,variableChannels) = (fourthMoments ./ n) ./ tempOne.^2;
      
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%    Compare two methods
%      percentDiff1 = abs(Statistics.Kurtosis(i,variableChannels) - matLabKURTOSIS) *100 ./ matLabKURTOSIS ;
%      percentDiff2 = abs(Statistics.Skews(i,variableChannels) - matLabSKEW) *100 ./ matLabSKEW ;
%      percentDiff3 = abs(Statistics.StdDevs(i,variableChannels) - matLabSTD) *100 ./ matLabSTD ;
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      

      Statistics.TotalSamples                        = Statistics.TotalSamples + n;  
      
      if (doAggregate)
         Statistics.Sums(1,variableChannels)         = Statistics.Sums(1,variableChannels)         + sums;
         Statistics.SumsSquared(1,variableChannels)  = Statistics.SumsSquared(1,variableChannels)  + sumsSquared;
         Statistics.SumsCubed(1,variableChannels)    = Statistics.SumsCubed(1,variableChannels)    + sumsCubed;   
         Statistics.SumsToFourth(1,variableChannels) = Statistics.SumsToFourth(1,variableChannels) + sumsToFourth;
      end

      return
      
   end % function compute_statistics(i)

%===============================================================================
