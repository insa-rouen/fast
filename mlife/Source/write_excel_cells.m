function result = write_excel_cells(sheetObj, data, location)
   try
      rangeStr = GetA1Range(data, location);
      rangeObj = sheetObj.Range(rangeStr);
      rangeObj.Value = data;
      result = rangeObj;
   catch err
      %fprintf('%s\n', err);
      result = [];
   end
end