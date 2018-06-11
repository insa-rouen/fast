function write_aggregate_statistics_as_text(progName, outputFilename, FileInfo, Statistics, realFmt)
   
   % Open output file.  
   
   fprintf( '    Writing aggregate statistics to: %s\n', outputFilename ); 

   fid = fopen( outputFilename, 'wt' );
   if ( fid < 0 )
      beep
      error( '  Could not open "%s" for writing.', outputFilename );
   end
   
   % Set up the header.
   what = 'These aggregate statistics';
   header = generate_text_header(progName, what);    
   fprintf( fid, '\n%s\n', header );

   fprintf( fid, '\nThe analysis was based upon %d rows from an aggregate of %d files.\n\n', FileInfo.TotLines, FileInfo.nFiles );
   
   % Generate the table.
   channelNames = FileInfo.Names; %cell(1, nChannels);
%    for i=1:nChannels
%       channelNames{i} = FileInfo.Names{i};
%    end
   ranges = Statistics.AggMaxima - Statistics.AggMinima;
   data = [Statistics.AggMinima', Statistics.AggMeans', Statistics.AggMaxima', Statistics.AggStdDevs', Statistics.AggSkews', Statistics.AggKurtosis', ranges'];
   dataNames = {'Minimum', 'Mean', 'Maximum', 'StdDev', 'Skewness', 'Kurtosis', 'Range'};
   if (FileInfo.HaveUnits)
      units = FileInfo.Units; %cell(1,nChannels);
%       for i=1:nChannels
%          units{i} = FileInfo.Units{Fatigue.ChanInfo(i).Chan};
%       end
      write_table_as_text(fid, channelNames, data, dataNames, realFmt, units);
   else
      write_table_as_text(fid, channelNames, data, dataNames, realFmt);
   end
      
   % Close the file.
   fclose( fid );
   
end % function write_aggregate_statistics_text()