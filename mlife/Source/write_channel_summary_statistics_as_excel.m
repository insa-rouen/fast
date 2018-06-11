function write_channel_summary_statistics_as_excel(sheetObj, iChan, progName, FileInfo, Statistics, realFmt)

   % Get the date and time.

   DateTime = clock;

   globalOffset = [1 1];
   % Create table headers, etc.
   [~, matVer] = strtok(version,'(');
   if ( FileInfo.HaveUnits )
      write_excel_cells( sheetObj, sprintf( 'These summary statistics for %s, with units of %s, were generated by %s on %s at %02d:%02d:%02d by MATLAB %s.', FileInfo.Names{iChan}, FileInfo.Units{iChan}, progName, date, uint8( DateTime(4:6) ), matVer ), globalOffset );
   
   else
      write_excel_cells( sheetObj, sprintf( 'These summary statistics for %s were generated by %s on %s at %02d:%02d:%02d by MATLAB %s.', FileInfo.Names{iChan}, progName, date, uint8( DateTime(4:6) ), matVer ), globalOffset );
   
   end % if
   globalOffset = globalOffset + [2 0];
   
  
   
   % Create table title 
   write_excel_cells( sheetObj, FileInfo.Names{iChan}, globalOffset );
   
   globalOffset = globalOffset + [1 0];
   
   % Create table Header
   write_excel_cells( sheetObj, 'Filename', globalOffset );
   headerOffset = globalOffset + [0 1];
  
   write_excel_cells( sheetObj, 'Minimum', headerOffset  );
   write_excel_cells( sheetObj, 'Mean', headerOffset + [0 1] );
   write_excel_cells( sheetObj, 'Maximum', headerOffset + [0 2] );
   write_excel_cells( sheetObj, 'StdDev', headerOffset + [0 3] );
   write_excel_cells( sheetObj, 'Skewness', headerOffset + [0 4] );
   write_excel_cells( sheetObj, 'Kurtosis', headerOffset + [0 5] );
   write_excel_cells( sheetObj, 'Range', headerOffset + [0 6] );
   
   nFiles = double(FileInfo.nFiles);
   
   % Write channel data
   for iFile = 1:nFiles
      % Channel name
      [~, fileName, ~] = fileparts(FileInfo.FileName{iFile});
      write_excel_cells( sheetObj, fileName, globalOffset + [iFile 0] );
         
      % Min
       write_excel_cells( sheetObj, sprintf( realFmt, Statistics.Minima(iFile,iChan)), headerOffset + [iFile 0] );
      % Mean
      write_excel_cells( sheetObj, sprintf( realFmt, Statistics.Means(iFile,iChan)), headerOffset + [iFile 1] );
      % Max
      write_excel_cells( sheetObj, sprintf( realFmt, Statistics.Maxima(iFile,iChan)), headerOffset + [iFile 2] );
      % StdDev
      write_excel_cells( sheetObj, sprintf( realFmt, Statistics.StdDevs(iFile,iChan)), headerOffset + [iFile 3] );
      % Skew
      write_excel_cells( sheetObj, sprintf( realFmt, Statistics.Skews(iFile,iChan)), headerOffset + [iFile 4] );
       % Kurtosis
      write_excel_cells( sheetObj, sprintf( realFmt, Statistics.Kurtosis(iFile,iChan)), headerOffset + [iFile 5] );
      % Range
      write_excel_cells( sheetObj, sprintf( realFmt, Statistics.Range(iFile,iChan)), headerOffset + [iFile 6] );
   end
   
   % Format table cells
   rangeObj = sheetObj.Range( convertR1C1toA1(headerOffset, headerOffset + [nFiles 6]) );
   format_number_cells(rangeObj, realFmt);
   
   % Format Column headers and table title
   rangeObj = sheetObj.Range( convertR1C1toA1([3 1], [3 headerOffset(2)+6]) );
   rangeObj.Font.Bold = 1;
   rangeObj.Merge(0);
   rangeObj.HorizontalAlignment = -4108;
   rangeObj = sheetObj.Range( convertR1C1toA1([4 1], [4 headerOffset(2)+6]) );
   rangeObj.Font.Bold = 1;
   
   % Format table cells
   rangeObj = sheetObj.Range(convertR1C1toA1(globalOffset, globalOffset + [nFiles headerOffset(2)+5]) );
   rangeObj.VerticalAlignment = 2;
   rangeObj.RowHeight = 18;
   rangeObj.Columns.AutoFit();
   rangeObj.HorizontalAlignment = -4108;
   rangeObj.Border.Value = 1;
   rangeObj.BorderAround(1,3);  
   
end