function globalOffset = create_shortterm_excel_table(globalOffset, sheetObj, iGroup, quantityType, Fatigue, FileInfo, fileMeanWindspeeds, realFmt)
   
   switch quantityType
      case 1
         tableName = sprintf( '%s  Short-term DELs at Fixed Mean for various S/N Curves\n', char(Fatigue.Groups(iGroup).name) );
      case 2
         tableName = sprintf( '%s  Short-term DELs at Zero Mean for various S/N Curves\n', char(Fatigue.Groups(iGroup).name) );
      case 3
         tableName = sprintf( '%s  Short-term DELs without Goodman Correction for various S/N Curves\n', char(Fatigue.Groups(iGroup).name) );
      case 4
         tableName = sprintf( '%s  Short-term Damage Rates (-/s) for various S/N Curves\n', char(Fatigue.Groups(iGroup).name) );
      case 5
         tableName = sprintf( '%s  Short-term Damage Rates (-/s) without Goodman Correction for various S/N Curves\n', char(Fatigue.Groups(iGroup).name) );
   end
   rangeObj = write_excel_cells( sheetObj, tableName, globalOffset +[0, 1]);
   rangeObj.HorizontalAlignment = -4131; %left
   rangeObj.VerticalAlignment   = 2;
   rangeObj.RowHeight           = 18; 
   rangeObj.WrapText            = 0;
   rangeObj.Font.Bold           = 1;
   nFiles = FileInfo.nFiles + double(Fatigue.DoAggregate);
   
   fileNames = cell(1,FileInfo.nFiles);
   maxNameLen = 0;
   for iFile=1:FileInfo.nFiles
      [~, name, ~] = fileparts(FileInfo.FileName{iFile});
      fileNames{iFile} = name;
      if(maxNameLen < length(name))
         maxNameLen = length(name);
      end
   end
   
   if(FileInfo.HaveUnits)
      windspeedUnits = FileInfo.Units{FileInfo.WSChan};
      timeUnits      = FileInfo.Units{FileInfo.TimeChan};
   else
      windspeedUnits = {};
      timeUnits      = {};
   end
   
      nGroupChannels  = length(Fatigue.Groups(iGroup).channelIndices);
      channelNames    = cell(1,  nGroupChannels);
     % if (quantityType < 3 || quantityType == 4)
         l_ult           = cell(1, nGroupChannels);
%       else
%          l_ult = [];
%       end
      if (quantityType < 4 )
         lmf             = cell(1, nGroupChannels);
      else
         lmf = [];
      end
      
      if(FileInfo.HaveUnits)
         channelUnits = cell(1, nGroupChannels);
      end
      for iCh=1:nGroupChannels
         channelNames{iCh}    = FileInfo.Names{Fatigue.ChanInfo(Fatigue.Groups(iGroup).channelIndices(iCh)).Chan};
         if(FileInfo.HaveUnits)
            channelUnits{iCh} = FileInfo.Units{Fatigue.ChanInfo(Fatigue.Groups(iGroup).channelIndices(iCh)).Chan};
         end
        % if (quantityType < 3 || quantityType == 4)
            l_ult{iCh}           = sprintf(realFmt,Fatigue.ChanInfo(Fatigue.Groups(iGroup).channelIndices(iCh)).LUlt);
       %  end
         if ( quantityType == 1 )
               lmf{iCh}          = sprintf(realFmt,Fatigue.ChanInfo(Fatigue.Groups(iGroup).channelIndices(iCh)).LMF);
         elseif ( quantityType < 4 )
            lmf{iCh}          = sprintf(realFmt,0.0);
         end
               
         
      end
      
      allSlopes      = Fatigue.Groups(iGroup).allSNSlopes;
      nGroupSlopes   = length(allSlopes);
      nDataRows      = double(nFiles*nGroupSlopes);
      data           = cell(nDataRows, nGroupChannels);
      elaspedTime    = zeros(nDataRows,1);
      dataPoints     = zeros(nDataRows,1);
      equivCycles    = zeros(nDataRows,1);
      meanWindspeeds = cell(nDataRows,1);
      slopes         = zeros(nDataRows,1);
      files          = cell(nDataRows,1);
      
      for iCh=1:nGroupChannels
         totalElapsedTime = 0;
         for iFile=1:nFiles
            
            for j=1:Fatigue.ChanInfo(Fatigue.Groups(iGroup).channelIndices(iCh)).NSlopes
               iSlope = find((Fatigue.Groups(iGroup).allSNSlopes == Fatigue.ChanInfo(Fatigue.Groups(iGroup).channelIndices(iCh)).SNslopes(j)) > 0);
               %iSlope = Fatigue.Groups(iGroup).SNSlopeMap(Fatigue.ChanInfo(Fatigue.Groups(iGroup).channelIndices(iCh)).SNslopes(j));
               rowOffset = (iSlope-1)*nFiles + iFile;
               slopes(rowOffset)         = Fatigue.ChanInfo(Fatigue.Groups(iGroup).channelIndices(iCh)).SNslopes(j);
               if (iFile > FileInfo.nFiles && Fatigue.DoAggregate)
                  files{rowOffset}          = 'Aggregate' ;
                  elaspedTime(rowOffset)    = totalElapsedTime;
                  meanWindspeeds{rowOffset} = sprintf(realFmt,fileMeanWindspeeds(iFile));
                  equivCycles(rowOffset)    = Fatigue.aggEquivalentCycles;
                  dataPoints(rowOffset)     = FileInfo.TotLines;
                  
               
                  switch quantityType
                     case 1 % fixed mean DEL
                        dataValue = Fatigue.Channel(Fatigue.Groups(iGroup).channelIndices(iCh)).aggDEL_FixedMeans(j);
                     case 2 % zero mean DEL
                        dataValue = Fatigue.Channel(Fatigue.Groups(iGroup).channelIndices(iCh)).aggDEL_ZeroMeans(j);
                     case 3 % no goodman correction DEL
                        dataValue = Fatigue.Channel(Fatigue.Groups(iGroup).channelIndices(iCh)).aggDEL_NoGoodman(j);
                     case 4 % short-term damage rate with goodman
                        dataValue = Fatigue.Channel(Fatigue.Groups(iGroup).channelIndices(iCh)).aggDamageRate(j);
                     case 5 % short-term damage rate without goodman
                        dataValue = Fatigue.Channel(Fatigue.Groups(iGroup).channelIndices(iCh)).aggDamageRate_NoGoodman(j);
                  end
               else
                  if (j == 1 )
                     totalElapsedTime = totalElapsedTime + Fatigue.ElapTime(iFile);
                  end
                  files{rowOffset}          = fileNames{iFile} ;
                  elaspedTime(rowOffset)    = Fatigue.ElapTime(iFile);
                  meanWindspeeds{rowOffset} = sprintf(realFmt,fileMeanWindspeeds(iFile));
                  equivCycles(rowOffset)    = Fatigue.ElapTime(iFile)*Fatigue.EquivalentFrequency;
                  dataPoints(rowOffset)     = FileInfo.nSamples(iFile);
               
               
                  switch quantityType
                     case 1 % fixed mean DEL
                        dataValue = Fatigue.File(iFile).Channel(Fatigue.Groups(iGroup).channelIndices(iCh)).DEL_FixedMeans(j);
                     case 2 % zero mean DEL
                        dataValue = Fatigue.File(iFile).Channel(Fatigue.Groups(iGroup).channelIndices(iCh)).DEL_ZeroMeans(j);
                     case 3 % no goodman correction DEL
                        dataValue = Fatigue.File(iFile).Channel(Fatigue.Groups(iGroup).channelIndices(iCh)).DEL_NoGoodman(j);
                     case 4 % short-term damage rate with goodman
                        dataValue = Fatigue.File(iFile).Channel(Fatigue.Groups(iGroup).channelIndices(iCh)).DamageRate(j);
                     case 5 % short-term damage rate without goodman
                        dataValue = Fatigue.File(iFile).Channel(Fatigue.Groups(iGroup).channelIndices(iCh)).DamageRate_NoGoodman(j);
                  end
               end
               if ( Fatigue.DEL_AsRange || quantityType > 3)
                  data{rowOffset,iCh} = sprintf(realFmt,dataValue);                
               else
                  data{rowOffset,iCh} = sprintf(realFmt,dataValue / 2.0);
               end
            end
         end
      end
      
     % tableData = create_short_term_table(nGroupChannels, nDataRows, data, slopes, files, channelNames, channelUnits, windspeedUnits, timeUnits, meanWindspeeds, elaspedTime, dataPoints, equivCycles, l_ult, lmf);

      
   
   if (FileInfo.HaveUnits)
      
      if (length(channelUnits) ~= nGroupChannels)
         error('must specify one unit for each channel!');
      end     
      unitsRow = 2;
   else      
      unitsRow = 1;
   end
   
   if (~isempty(l_ult))
      hasUltimate = true;
      if(~isempty(lmf))
         hasFixedMean = true;
         firstDataRow = unitsRow + 3;
         %tableData{unitsRow+1:unitsRow+2,1} = {'L_Ult';'L_MF'};
         write_excel_cells( sheetObj, 'L_Ult', globalOffset + [unitsRow+1 1]);
         write_excel_cells( sheetObj, 'L_MF', globalOffset + [unitsRow+2 1]);
      else
         hasFixedMean = false;
         firstDataRow = unitsRow + 2;
         %tableData{unitsRow+1:unitsRow+1,1} = {'L_Ult'};
         write_excel_cells( sheetObj, 'L_Ult', globalOffset + [unitsRow+1 1]);
      end
   else
      hasUltimate = false;
      hasFixedMean = false;
      firstDataRow = unitsRow + 1;
   end
   
   

   % Create the table header row
   %                        m     Filename  Channel1    Channel2   Channel3    ...      ChannelN  MeanWindspeed  Elapsed Time   Datapoints   Equivalent Cycles

   %ableData{1,2:3} = {'m','Filename'};
   write_excel_cells( sheetObj, 'm', globalOffset + [1,2]);
   write_excel_cells( sheetObj, 'Filename', globalOffset + [1,3]);
   %tableData{1,4:3+nGroupChannels} = channelNames;
   write_excel_cells( sheetObj,channelNames, globalOffset + [1,4]);
   %tableData{1,4+nGroupChannels:7+nGroupChannels} = {'MeanWindspeed',  'Elapsed Time',   'Datapoints',   'Equivalent Cycles'};
   write_excel_cells( sheetObj,{'MeanWindspeed',  'Elapsed Time',   'Datapoints',   'Equivalent Cycles'},globalOffset + [1,4+nGroupChannels]);
   % Create units row
   if (FileInfo.HaveUnits)
      %tableData{2,4:3+nGroupChannels} = channelUnits;
      write_excel_cells( sheetObj, channelUnits, globalOffset + [2,4]);
      %tableData{2,4+nGroupChannels}   = windspeedUnits;
      write_excel_cells( sheetObj, windspeedUnits, globalOffset + [2,4+nGroupChannels]);
      %tableData{2,5+nGroupChannels}   = timeUnits;
      write_excel_cells( sheetObj, timeUnits, globalOffset + [2,5+nGroupChannels]);
   end
   
   % Create Ultimate load and Fixed mean load entries
   if (hasUltimate)
      %tableData{unitsRow+1, 4:3+nGroupChannels} = l_ult;
      rangeObj = write_excel_cells( sheetObj, l_ult, globalOffset + [unitsRow+1,4]);
      format_number_cells(rangeObj,realFmt);
   end
   if (hasFixedMean)
      %tableData{unitsRow+2, 4:3+nGroupChannels} = lmf;
      rangeObj = write_excel_cells( sheetObj, lmf, globalOffset + [unitsRow+2,4]);
      format_number_cells(rangeObj,realFmt);
   end
   
   % Create m labels
   %tableData{firstDataRow:firstDataRow+nDataRows-1,2} = slopes;
   rangeObj = write_excel_cells( sheetObj, slopes, globalOffset + [firstDataRow,2]);
   %rangeObj.Font.Bold = 1;
   
   % Create filenames column
   %tableData{firstDataRow:firstDataRow+nDataRows-1,3} = files;
   write_excel_cells( sheetObj, files, globalOffset + [firstDataRow,3]);
   
   % Create Mean wind speed column
   %tableData{firstDataRow:firstDataRow+nDataRows-1,4+nGroupChannels} = meanWindspeeds;
   rangeObj = write_excel_cells( sheetObj, meanWindspeeds, globalOffset + [firstDataRow,4+nGroupChannels]);
   format_number_cells(rangeObj,realFmt);
   % Create Elapsed time column
   %tableData{firstDataRow:firstDataRow+nDataRows-1,5+nGroupChannels} = elaspedTime;
   write_excel_cells( sheetObj, elaspedTime, globalOffset + [firstDataRow,5+nGroupChannels]);
   
   % Create # of datapoints in file column
   %tableData{firstDataRow:firstDataRow+nDataRows-1,6+nGroupChannels} = dataPoints;
   write_excel_cells( sheetObj, dataPoints, globalOffset + [firstDataRow,6+nGroupChannels]);
   
   % Create # of equivalent cycles in files column
   %tableData{firstDataRow:firstDataRow+nDataRows-1,7+nGroupChannels} = equivCycles;
   write_excel_cells( sheetObj, equivCycles, globalOffset + [firstDataRow,7+nGroupChannels]);
   
   % Create data
   %tableData{firstDataRow:firstDataRow+nDataRows-1,4:3+nGroupChannels} = data;
   rangeObj = write_excel_cells( sheetObj, data, globalOffset + [firstDataRow,4]);
   format_number_cells(rangeObj,realFmt);
   % format headers
   rangeObj = sheetObj.Range(convertR1C1toA1(globalOffset+[1, 1], globalOffset+[firstDataRow-1, 1]) );
   rangeObj.Font.Bold = 1;
   rangeObj = sheetObj.Range(convertR1C1toA1(globalOffset+[1, 1], globalOffset+[unitsRow, 7+nGroupChannels]) );
   rangeObj.Font.Bold = 1;
   
   
   % format table
   rangeObj = sheetObj.Range(convertR1C1toA1(globalOffset+[1, 1], globalOffset+[firstDataRow+nDataRows-1, 7+nGroupChannels]) );
   rangeObj.Columns.AutoFit();
   rangeObj.HorizontalAlignment = -4108;
   rangeObj.VerticalAlignment = 2;
   rangeObj.RowHeight = 18;
   rangeObj.Border.Value = 1;
   rangeObj.BorderAround(1,3);
   
   rangeObj = sheetObj.Range(convertR1C1toA1(globalOffset+[unitsRow, 1], globalOffset+[unitsRow, 7+nGroupChannels]) );
   rangeObj.Borders.Item(4).LineStyle = 9; % double line on bottom border
   
   %tableData.setColumnFormat(4:4+nGroupChannels,FileInfo.RealFmt);
   %tableData.setColumnTextAlignment('c')
   globalOffset = globalOffset + [firstDataRow+nDataRows + 3, 0];
end