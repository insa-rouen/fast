function write_compact_lifetime_results_as_excel(progName, RootName, FileInfo, Fatigue, windChannelMeans, realFmt)
	  
   fprintf( '    Writing lifetime estimates to:\n' );

   % Set up the name of the Excel file.  Delete the file if it already exists

   XLSfile = [ RootName, '_Lifetime.xlsx' ];

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
   nSheets      = workbookObj.Worksheets.Count;
   for i=1:nSheets -1
      workbookObj.Worksheets.Item(1).Delete;
   end
  
   % If you want to see the editing within excel enable the next line for
   % debugging only
   % excelObj.Visible = 1;
   
   % Create a worksheet with wind speed distribution properties and
   % associated bins
   sheetObj      = workbookObj.Worksheets.Item(1);
   sheetObj.Name = 'Wind Speed Distribution';
   
   write_windspeed_distribution_as_excel( progName, sheetObj, windChannelMeans, FileInfo, Fatigue );
   
  
   % Load-range bins
   %
  
   if ( Fatigue.BinCycles )
      
      sheetObj      = workbookObj.Worksheets.Add();
      sheetObj.Name = 'Load-Range Bins'; 
      write_load_range_bins_as_excel( progName, sheetObj, FileInfo, Fatigue );
      
   end % if Fatigue.BinCycles
   
   % Create the worksheet for Lifetime DELs
   sheetObj      = workbookObj.Worksheets.Add();
   sheetObj.Name = 'Lifetime DELs';
   write_compact_lifetime_dels_as_excel( sheetObj, progName, FileInfo, Fatigue, realFmt );
   
   % Create the worksheet for Lifetime damage
   sheetObj      = workbookObj.Worksheets.Add();
   sheetObj.Name = 'Lifetime Damage';
   write_compact_lifetime_damage_as_excel( sheetObj, progName, FileInfo, Fatigue, realFmt );
   
   % Save the workbook, close, and kill the activeX server object
   workbookObj.SaveAs(XLSfile);
   workbookObj.Close;
   delete(excelObj);

end