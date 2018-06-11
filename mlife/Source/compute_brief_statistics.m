function [Statistics] = compute_brief_statistics( i, data, Statistics, nLines )
% Generate statistics of data.
%
% This function calculates the following statistics for data
% stored in the FileInfo data structure:
%     Minimum plus corresponding index
%     Mean
%     Maximum plus corresponding index
%     Range (Maximum-Minimum)
%
% It processes one dataset at a time and adds the computed statistics
% to the original Statistics data structure.  
%
% Syntax is:  compute_brief_statistics( i, data, Statistics, nLines )
%
%     where:
%       i          -  index of input file which is having its statistics calculated.
%       data       - the channel data for the ith file
%       Statistics - statistics structure
%       nLines     - number of datapoints in the input file
%
% Example:
%     compute_brief_statistics( 1, data, Statistics, 1200 )
%    
% Called by: mlife
      % Individual-file means.
    
      RowRange = 1:nLines; %Check this GJH 24-May-2011      
      [Statistics.Minima(i,:), Statistics.MinInds(i,:)] = min(data(RowRange,:));
      [Statistics.Maxima(i,:), Statistics.MaxInds(i,:)] = max(data(RowRange,:));
      Statistics.Means(i,:)       = mean    ( data(RowRange,:) );
      Statistics.Range(i,:)       = Statistics.Maxima(i,:) - Statistics.Minima(i,:);
      
      return
      
   end % function compute_statistics(i)

