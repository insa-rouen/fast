function Statistics = compute_brief_aggregate_statistics(nChannels, nFiles, Statistics)
% Generate statistics of data.
%
% This function calculates the following statistics for the aggregate of
% data across all input files.  Results are stored in the FileInfo
% structure.
%     Minimum plus corresponding index in the corresponding data file
%     Mean
%     Maximum plus corresponding index in the corresponding data file
%     Range (Maximum-Minimum)
%
%
% Syntax is:  compute_brief_aggregate_statistics(nChannels, nFiles, Statistics)
%
%     where:
%        nChannels   - number of data channels
%        nFiles      - number of files
%        Statistics  - statistics structure 
%       
% Example:
%     compute_brief_aggregate_statistics(10, 2, Statistics)
%
%
%  Called by: mlife


   fprintf('  Generating aggregate statistics.\n');
   n              = Statistics.TotalSamples;
   sums           = Statistics.Sums;
   channelIndices = uint32(0:nChannels-1);
   offset = channelIndices*uint32(nFiles);

   [Statistics.AggMinima, Statistics.AggMinFileNum ] = min( Statistics.Minima );
   Statistics.AggMinInds = Statistics.MinInds(uint32(Statistics.AggMinFileNum) +  offset);

   [Statistics.AggMaxima, Statistics.AggMaxFileNum ] = max( Statistics.Maxima );
   Statistics.AggMaxInds = Statistics.MaxInds(uint32(Statistics.AggMaxFileNum) +  offset);
   
   Statistics.AggRange = Statistics.AggMaxima - Statistics.AggMinima;
   
   fprintf('    Done generating aggregate statistics.\n');
   constChannels       = (abs(Statistics.AggRange) < realmin('single'));
   variableChannels    = ~constChannels;
      
   Statistics.AggMeans(constChannels)   = Statistics.AggMinima(constChannels);
   Statistics.AggStdDevs(constChannels) = 0.0;
   Statistics.AggSkews(constChannels)   = 0.0;
   
   means   = sums(variableChannels) ./ n;
   Statistics.AggMeans(variableChannels) = means;
end % function generate_aggregate_statistics()

   