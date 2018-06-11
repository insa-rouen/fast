% Format table cells
function format_number_cells(rangeObj, realFmt)
   [~, precision, subtype] = parse_format(realFmt); 
   if (strcmp(subtype,'e') || strcmp(subtype,'E') )
      decimals = repmat('0',1,precision);
      rangeObj.NumberFormat = ['0.' decimals 'E+000'];
   elseif (strcmp(subtype,'f') || strcmp(subtype,'F') )
      decimals = repmat('0',1,precision);
      rangeObj.NumberFormat = ['0.' decimals];
   end
end