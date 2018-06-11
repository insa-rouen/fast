function globalOffset = write_lifetime_preamble_as_excel(globalOffset, progName, sheetObj, FileInfo, Fatigue, realFmt)

   
   write_excel_cells( sheetObj, 'Total number of samples', globalOffset + [1 1]);
   write_excel_cells( sheetObj, 'Lifetime period', globalOffset + [2 1]);
   write_excel_cells( sheetObj, 'seconds', globalOffset + [2 6]);
   
   % Merge columns
   rangeObj = sheetObj.Range(convertR1C1toA1(globalOffset + [1 1], globalOffset + [1 3]) );
   rangeObj.Merge(1);
   rangeObj = sheetObj.Range(convertR1C1toA1(globalOffset + [2 1], globalOffset + [2 3]) );
   rangeObj.Merge(1);
   
   
   rangeObj = sheetObj.Range(convertR1C1toA1(globalOffset + [1 1], globalOffset + [2 3]) );
   rangeObj.Font.Bold = 1;
   rangeObj.HorizontalAlignment = -4131; % left
   rangeObj.VerticalAlignment = 2; % centered
   rangeObj.RowHeight = 18;
   
   
   write_excel_cells( sheetObj, sum(FileInfo.nSamples(:)), globalOffset + [1 5]);
   write_excel_cells( sheetObj, sprintf( realFmt,Fatigue.DesignLife), globalOffset + [2 5]);
   
   rangeObj = sheetObj.Range(convertR1C1toA1(globalOffset + [1 5], globalOffset + [2 5]) );
   rangeObj.HorizontalAlignment = -4152; % right aligned
   
   globalOffset = globalOffset + [2 0];
   
end