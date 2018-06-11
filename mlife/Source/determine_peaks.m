function [ peaks, nPeaks ] = determine_peaks(data)
% Identify peaks and troughs in the time series.  The first and last
% points are considered peaks or troughs.  Sometimes the peaks can be flat
% for a while, so we have to deal with that nasty situation.

%
% Syntax is:  [peaks, nPeaks] = determine_peaks(timeSeriesData);
%
% where:
%        data           - array of time series data.                      
%        nPeaks         - number of identified peaks
%        peaks          - an array of the identified peaks

% Example:
%     [peaks, nPeaks] = determine_peaks(timeSeriesData);
%
% See also  mlife


      % This is a Matlab vector-optimized rountine.  Sorry if it is hard to understand.  GJH
      % It was verified against a much slower version (see MCrunch)
      
     data       = [data((data(2:end) - data(1:end-1) ~=0));data(end)];
     backdiff   = data(2:end-1) - data(1:end-2);
     forwdiff   = data(3:end) - data(2:end-1);
     signchange = sign(backdiff) + sign(forwdiff) ;
     peakInds   = find(signchange == 0) + 1;
     peaks      = [data(1); data(peakInds); data(end)];
     nPeaks     = length(peaks);

end % function [ Peaks, NumPeaks ] = GetPeaks( data )