function write_table_as_text(fid, channelNames, data, dataNames, realFmt, units)
% Write lifetime predictions to a text file.

   nChannels = length(channelNames);
   nData = length(dataNames);
   % Generate the table.
   unitsCol = 0;
   table = DataTable();
   table{1,1} = 'Channel';
   if ( nargin == 7 )
      table{1,2} = 'Units';
      table{2:nChannels+1,2} = units';
      unitsCol = 1;
   end
   table{1,2+unitsCol:nData+1+unitsCol} = dataNames;
   table{2:nChannels+1,1} = channelNames';  
   table{2:nChannels+1,2+unitsCol:nData+1+unitsCol} = data;
   table.setColumnFormat(2+unitsCol:1+unitsCol+nData,realFmt);
   table.setColumnTextAlignment('c')
   table.toText(fid, 'delimiter',' ');


   fprintf( fid, '\n' );

end % function WrLifeTxt
%=======================================================================
