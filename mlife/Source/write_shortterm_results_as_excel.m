function write_shortterm_results_as_excel(progName, outputFilename, FileInfo, Fatigue, windChannelMeans, realFmt)
   fprintf( '    Writing short-term fatigue results to:\n' );

   % Set up the name of the Excel file.  Delete the file if it already exists

   XLSfile = [ outputFilename, '_Short-term.xlsx' ];

   fprintf( '      %s\n', XLSfile );
   fprintf('\n');
   
   DelFile( XLSfile );


   % Create an activeX server connection to Excel
   try
      excelObj = actxserver('Excel.Application'); 
   catch err
      fprintf('Warning:  Excel is not installed on this machine.\nSkipping Excel Output.\n');
      return
   end 
   
   % Create the workbook and remove unwanted default worksheets
   workbookObj  = excelObj.Workbooks.Add();
   nSheets = workbookObj.Worksheets.Count;
   for i=1:nSheets -1
      workbookObj.Worksheets.Item(1).Delete;
   end
  
   % If you want to see the editing within excel enable the next line for
   % debugging only
   % excelObj.Visible = 1;
   
   % Create the worksheet for Lifetime DELs
   sheetObj = workbookObj.Worksheets.Item(1);
   
    % Load-range bins
   %
  
   if ( Fatigue.BinCycles)
      
      % sheetObj      = workbookObj.Worksheets.Add();
      sheetObj.Name = 'Load-Range Bins'; 
      write_load_range_bins_as_excel(progName, sheetObj, FileInfo, Fatigue, true);
      sheetObj = workbookObj.Worksheets.Add();
   end % if Fatigue.BinCycles
   
   sheetObj.Name = 'Short-term DELs';
   write_shortterm_dels_as_excel(progName, sheetObj, FileInfo, Fatigue, windChannelMeans, realFmt)
   
   
   sheetObj = workbookObj.Worksheets.Add();
   sheetObj.Name = 'Short-term Damage-Rates';
   write_shortterm_damage_rate_as_excel(progName, sheetObj, FileInfo, Fatigue, windChannelMeans, realFmt)
   
       % Save the workbook, close, and kill the activeX server object
   workbookObj.SaveAs(XLSfile);
   workbookObj.Close;
   delete(excelObj);
   
end