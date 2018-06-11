function rangeA1FormatStr = convertR1C1toA1(startCell, endCell)
   colVal = startCell(2);
   startStr = sprintf('%d',startCell(1)); %num2str(startCell(1))
   endStr = sprintf('%d',endCell(1));  %num2str(endCell(1))
   if (colVal < 27)
      startStr = [char(64 + colVal) startStr];
   else
      firstLetter = char(64 + fix((colVal-1) / 26));
      secondLetter = char(65 + mod((colVal-1), 26));
      startStr = [firstLetter secondLetter startStr];
   end   

   colVal = endCell(2);
   if (colVal < 27)
      endStr = [char(64 + colVal) endStr];
   else
      firstLetter = char(64 + fix((colVal-1) / 26));
      secondLetter = char(65 + mod((colVal-1), 26));
      endStr = [firstLetter secondLetter endStr];
   end
   rangeA1FormatStr = [ startStr ':' endStr ];
end

