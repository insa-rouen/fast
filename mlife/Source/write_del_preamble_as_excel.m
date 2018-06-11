function globalOffset = write_del_preamble_as_excel(globalOffset, progName, sheetObj, FileInfo, Fatigue)

   write_excel_cells( sheetObj, 'Total number of samples', globalOffset + [1 1]);
   %write_excel_cells( sheetObj, 'Lifetime period', globalOffset + [2 1]);
   write_excel_cells( sheetObj, 'Equivalent load frequency', globalOffset + [2 1]);
   write_excel_cells( sheetObj, 'Number of equivalent cycles', globalOffset + [3 1]);
   
   % Merge columns
   rangeObj = sheetObj.Range(convertR1C1toA1(globalOffset + [1 1], globalOffset + [1 3]) );
   rangeObj.Merge(1);
   rangeObj = sheetObj.Range(convertR1C1toA1(globalOffset + [2 1], globalOffset + [2 3]) );
   rangeObj.Merge(1);
   rangeObj = sheetObj.Range(convertR1C1toA1(globalOffset + [3 1], globalOffset + [3 3]) );
   rangeObj.Merge(1);
   
   rangeObj = sheetObj.Range(convertR1C1toA1(globalOffset + [1 1], globalOffset + [3 3]) );
   rangeObj.Font.Bold = 1;
   rangeObj.HorizontalAlignment = -4131; % left
   rangeObj.VerticalAlignment = 2; % centered
   rangeObj.RowHeight = 18;
   
   
   write_excel_cells( sheetObj, sum(FileInfo.nSamples(:)), globalOffset + [1 4]);
   write_excel_cells( sheetObj, sprintf( '%g Hz', Fatigue.EquivalentFrequency), globalOffset + [2 4]);
   write_excel_cells( sheetObj, Fatigue.lifetimeEquivalentCycles, globalOffset + [3 4]);
   write_excel_cells( sheetObj, Fatigue.RFPerStr, globalOffset + [3 5]);
   
   rangeObj = sheetObj.Range(convertR1C1toA1(globalOffset + [1 3], globalOffset + [3 4]) );
   rangeObj.HorizontalAlignment = -4152; % right aligned
   
   globalOffset = globalOffset + [5 0];
   
   if ( Fatigue.DEL_AsRange )
      write_excel_cells( sheetObj, 'Damage equivalent loads are given as peak-to-valley ranges', globalOffset+[0 1]);
   else
      write_excel_cells( sheetObj, 'Damage equivalent loads are given as one-sided amplitudes', globalOffset+[0 1]);
   end
  
   globalOffset = globalOffset + [1 0];
end