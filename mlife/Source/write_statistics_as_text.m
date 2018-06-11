function write_statistics_as_text(iFile, progName, outputFilename, FileInfo, Statistics, realFmt)
   
   % Open output file.  
   
   fprintf( '    Writing statistics to: %s\n', outputFilename ); 

   fid = fopen( outputFilename, 'wt' );
   if ( fid < 0 )
      beep;
      error( '  Could not open "%s" for writing.', outputFilename );
   end
   
   % Set up the header.
   what = 'These statistics';
   header = generate_text_header(progName, what);    
   fprintf( fid, '\n%s\n', header );

   fprintf( fid, '\nThe analysis was based upon %d rows.\n', FileInfo.nSamples(iFile) );
   if ( isfield( FileInfo, 'Title' ) )
      fprintf( fid, '\n%s\n\n', FileInfo.Title{iFile} );
   end % if
         
   % Generate the table.
   
   channelNames = FileInfo.Names; %cell(1, nChannels);
%    for i=1:nChannels
%       channelNames{i} = FileInfo.Names{i};
%    end
  
   data = [Statistics.Minima(iFile,:)', Statistics.Means(iFile,:)', Statistics.Maxima(iFile,:)', Statistics.StdDevs(iFile,:)', Statistics.Skews(iFile,:)', Statistics.Kurtosis(iFile,:)',Statistics.Range(iFile,:)'];
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
   
end % function write_statistics_text()