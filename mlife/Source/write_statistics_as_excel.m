function write_statistics_as_excel(progName, fileName, FileInfo, Statistics, realFmt)
	  
   fprintf( '    Writing statistics to:\n' );

   % Set up the name of the Excel file.  Delete the file if it already exists

   
   fprintf( '      %s\n', fileName );

   DelFile( fileName );


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
   
   % Create the worksheet for first file
   sheetObj = workbookObj.Worksheets.Item(1);
   sheetObj.Name = sprintf('File1');
     
   % Create a sheet for the aggregate statistics if there was more than one input file.
   write_file_statistics_as_excel(sheetObj, progName, 1, FileInfo, Statistics, realFmt);
   
   if (FileInfo.nFiles > 1)   
      for iFile = 2:FileInfo.nFiles
         sheetObj = workbookObj.Worksheets.Add();
         sheetObj.Name = sprintf('File%d',iFile);

         % Create a sheet for the aggregate statistics if there was more than one input file.
         write_file_statistics_as_excel(sheetObj, progName, iFile, FileInfo, Statistics, realFmt);
      end % for iFile
      
      % Create aggregate worksheet
      sheetObj = workbookObj.Worksheets.Add();
      sheetObj.Name = 'Aggregate';
      write_aggregate_statistics_as_excel(sheetObj, progName, FileInfo, Statistics, realFmt);
   end % if
   
   
   % Save the workbook, close, and kill the activeX server object
   workbookObj.SaveAs(fileName);
   workbookObj.Close;
   delete(excelObj);
   
   
   
end % function write_statistics_as_excel(settingsFile)
