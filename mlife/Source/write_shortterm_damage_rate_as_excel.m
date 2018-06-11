function write_shortterm_damage_rate_as_excel(progName, sheetObj, FileInfo, Fatigue, windChannelMeans, realFmt)
  
   
   % Set up the header.
   what     = 'These short-term damage rate estimates';
   header   = generate_text_header(progName, what);    
   rangeObj = write_excel_cells( sheetObj, header, [1,1] );
   %rangeObj = sheetObj.Range(convertR1C1toA1(globalOffset+[0 0], globalOffset+[0 4+nAllSlopes]) );
   %rangeObj.Merge(1);
   %rangeObj.Font.Bold = 1;
   rangeObj.HorizontalAlignment = -4131; %left
   rangeObj.VerticalAlignment   = 2;
   rangeObj.RowHeight           = 18; 
   rangeObj.WrapText            = 0;
   
   %nChannels    = size( Fatigue.ChanInfo , 2 );
   %channelNames = cell(1, nChannels);
   %nFiles       = FileInfo.nFiles;
   
%    for i=1:nChannels
%       channelNames{i} = FileInfo.Names{Fatigue.ChanInfo(i).Chan};
%    end
   %data = [Fatigue.File(iFile).DEL_FixedMean(:), Fatigue.File(iFile).DEL_ZeroMean(:), Fatigue.File(iFile).DEL_RangeOnly(:)];
   
   
   
   
   globalOffset = [5,0];
   
   for iGroup = 1:Fatigue.nGroups
      if ( Fatigue.GoodmanFlag == 1 ||  Fatigue.GoodmanFlag == 2)         
            globalOffset = create_shortterm_excel_table(globalOffset, sheetObj, iGroup, 4, Fatigue, FileInfo, windChannelMeans, realFmt);
      end
      if ( Fatigue.GoodmanFlag == 0 ||  Fatigue.GoodmanFlag == 2)
         globalOffset = create_shortterm_excel_table(globalOffset, sheetObj, iGroup, 5, Fatigue, FileInfo, windChannelMeans, realFmt);
         
      end
   end

  
   %fclose( fid );
 
     
end % function write_shortterm_dels_as_excel(...)