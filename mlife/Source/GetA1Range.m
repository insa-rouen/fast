function rangeA1FormatStr = GetA1Range(data, offset)
   nRows = size(data,1);
   if ( isa(data, 'char'))
      nColumns = 1;
   else
      nColumns = size(data,2);
   end
   endCell = offset + [nRows-1 nColumns-1];
   rangeA1FormatStr = convertR1C1toA1(offset, endCell);
end