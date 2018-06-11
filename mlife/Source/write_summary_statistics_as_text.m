function write_summary_statistics_as_text( outputDirectory, progName, iChan, FileInfo, Statistics, realFmt )

       % Find the longest input-file name.
%       [~, fileName, ~] = fileparts(FileInfo.FileName{1});
%       maxFilenameLength = size( fileName, 2 );
%       fileNames = cell(1,FileInfo.nFiles);
      maxFilenameLength = 0;
      for iFile=1:FileInfo.nFiles
         [~, fileName, ~] = fileparts(FileInfo.FileName{iFile});
         fileNames{iFile} = fileName;
         if ( size( fileName, 2 ) > maxFilenameLength )
            maxFilenameLength = size( fileName, 2 );
         end % if
      end % for

      
      outputFilename = [ FileInfo.Names{iChan} '_Statistics.txt' ];
      if ( ~isempty(outputDirectory) )      
         outputFilename = [ outputDirectory outputFilename ];
      end
   % Open output file.
   
   fprintf( '    Writing summary statistics to: %s\n', outputFilename ); 

   fid = fopen( outputFilename, 'wt' );
   if ( fid < 0 )
      beep
      error( '  Could not open "%s_Statistics.txt" for writing.', FileInfo.Names{iChan} );
   end
   
   % Set up the header.
   if ( FileInfo.HaveUnits )
      what = sprintf( '\nThese summary statistics for %s, with units of %s,', ...
         FileInfo.Names{iChan}, FileInfo.Units{iChan});
   else
      what = sprintf( '\nThese summary statistics for %s', ...
         FileInfo.Names{iChan} );
   end % if
   header = generate_text_header(progName, what);    
   fprintf( fid, '\n%s\n', header );

  
   % Generate the table.
   
   data = [Statistics.Minima(:,iChan) Statistics.Means(:,iChan) Statistics.Maxima(:,iChan) Statistics.StdDevs(:,iChan) Statistics.Skews(:,iChan) Statistics.Kurtosis(:,iChan) Statistics.Range(:,iChan)];
   dataNames = {'Minimum', 'Mean', 'Maximum', 'StdDev', 'Skewness', 'Kurtosis', 'Range'};
   
   write_table_as_text(fid, fileNames, data, dataNames, realFmt);

      
   % Close the file.
   fclose( fid );
   
end % function write_aggregate_statistics_text()