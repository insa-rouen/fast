function Statistics = compute_aggregate_statistics(nChannels, nFiles, Statistics)
% Generate statistics of data.
%
% This function calculates the following statistics for the aggregate of
% data across all input files.  Results are stored in the FileInfo
% structure.
%     Minimum plus corresponding index in the corresponding data file
%     Mean
%     Maximum plus corresponding index in the corresponding data file
%     Standard Deviation
%     Skewness
%     Kurtosis
%     Range (Maximum-Minimum)
%
% Since we do not have access to the aggregate of the time series data
% across all input files, we have had to store some intermediate data which
% in turn can be used to calculate the aggregate mean, standard deviation,
% and skewness as programmed below.
%
% Syntax is:  compute_aggregate_statistics(nChannels, nFiles, Statistics)
%
%     where:
%        nChannels   - number of data channels
%        nFiles      - number of files
%        Statistics  - statistics structure 
%       
% Example:
%     compute_aggregate_statistics(10, 2, Statistics)
%
%
%  Called by: mlife

   
   channelIndices = uint32(0:nChannels-1);
   offset = channelIndices*uint32(nFiles);

   fprintf('  Generating aggregate statistics.\n');

   % helper variables for generating longer equations used below
   n              = Statistics.TotalSamples;
   sums           = Statistics.Sums;
   sumsSquared    = Statistics.SumsSquared;
   sumsCubed      = Statistics.SumsCubed;
   sumsToFourth   = Statistics.SumsToFourth;

   
   [Statistics.AggMinima, Statistics.AggMinFileNum ] = min( Statistics.Minima );
   Statistics.AggMinInds = Statistics.MinInds(uint32(Statistics.AggMinFileNum) +  offset);

   [Statistics.AggMaxima, Statistics.AggMaxFileNum ] = max( Statistics.Maxima );
   Statistics.AggMaxInds = Statistics.MaxInds(uint32(Statistics.AggMaxFileNum) +  offset);
   
   Statistics.AggRange = Statistics.AggMaxima - Statistics.AggMinima;
   
   constChannels       = (abs(Statistics.AggRange) < realmin('single'));
   variableChannels    = ~constChannels;
      
   Statistics.AggMeans(constChannels)   = Statistics.AggMinima(constChannels);
   Statistics.AggStdDevs(constChannels) = 0.0;
   Statistics.AggSkews(constChannels)   = 0.0;
   
   means   = sums(variableChannels) ./ n;
   Statistics.AggMeans(variableChannels) = means;
   
   % NOTE: all higher moments and sums have already been zeroed out by
   % compute_statistics() function if the channel's range
   
   secondMoments = sumsSquared(variableChannels) - (2*means.*sums(variableChannels)) + n*means.^2;
   thirdMoments  = sumsCubed(variableChannels) -(3*means.*sumsSquared(variableChannels)) + (3*(means.^2).*sums(variableChannels))-n*means.^3;
   fourthMoments = sumsToFourth(variableChannels) -(4*sumsCubed(variableChannels).*means) + (6*sumsSquared(variableChannels).*(means.^2)) -(4*sums(variableChannels).*(means.^3)) + n*means.^4;
   tempOne       = secondMoments ./ (n);
   
   Statistics.AggStdDevs(variableChannels)  = sqrt(secondMoments ./ (n-1));
   Statistics.AggSkews(variableChannels)    = (thirdMoments ./ n) ./ (sqrt(tempOne).^3);
   Statistics.AggKurtosis(variableChannels) =  (fourthMoments ./ n) ./ tempOne.^2;
   
   fprintf('    Done generating aggregate statistics.\n');

end % function generate_aggregate_statistics()

   