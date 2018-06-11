function tableData = create_shortterm_text_table(iGroup, quantityType, Fatigue, FileInfo, fileMeanWindspeeds)
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
         l_ult           = zeros(1, nGroupChannels);
    %  else
    %     l_ult = [];
    %  end
      if (quantityType < 4 )
         lmf             = zeros(1, nGroupChannels);
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
            l_ult(iCh)           = Fatigue.ChanInfo(Fatigue.Groups(iGroup).channelIndices(iCh)).LUlt;
        % end
         if( quantityType == 1 )
               lmf(iCh)             = Fatigue.ChanInfo(Fatigue.Groups(iGroup).channelIndices(iCh)).LMF;
         end
               
         
      end
      
      allSlopes      = Fatigue.Groups(iGroup).allSNSlopes;
      nGroupSlopes   = length(allSlopes);
      nDataRows      = nFiles*nGroupSlopes;
      data           = cell(nDataRows, nGroupChannels);
      elaspedTime    = zeros(nDataRows,1);
      dataPoints     = zeros(nDataRows,1);
      equivCycles    = zeros(nDataRows,1);
      meanWindspeeds = zeros(nDataRows,1);
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
                  meanWindspeeds(rowOffset) = fileMeanWindspeeds(iFile);
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
                  meanWindspeeds(rowOffset) = fileMeanWindspeeds(iFile);
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
                  data{rowOffset,iCh} = dataValue;                
               else
                  data{rowOffset,iCh} = dataValue / 2.0;
               end
            end
         end
      end
      
     % tableData = create_short_term_table(nGroupChannels, nDataRows, data, slopes, files, channelNames, channelUnits, windspeedUnits, timeUnits, meanWindspeeds, elaspedTime, dataPoints, equivCycles, l_ult, lmf);

      
      tableData = DataTable();
   
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
         tableData{unitsRow+1:unitsRow+2,1} = {'L_Ult';'L_MF'};
      else
         hasFixedMean = false;
         firstDataRow = unitsRow + 2;
         tableData{unitsRow+1:unitsRow+1,1} = {'L_Ult'};
      end
   else
      hasUltimate = false;
      hasFixedMean = false;
      firstDataRow = unitsRow + 1;
   end
   
   

   % Create the table header row
   %                        m     Filename  Channel1    Channel2   Channel3    ...      ChannelN  MeanWindspeed  Elapsed Time   Datapoints   Equivalent Cycles

   tableData{1,2:3} = {'m','Filename'};
   tableData{1,4:3+nGroupChannels} = channelNames;
   tableData{1,4+nGroupChannels:7+nGroupChannels} = {'MeanWindspeed',  'Elapsed Time',   'Datapoints',   'Equivalent Cycles'};
   
   % Create units row
   if (FileInfo.HaveUnits)
      tableData{2,4:3+nGroupChannels} = channelUnits;
      tableData{2,4+nGroupChannels}   = windspeedUnits;
      tableData{2,5+nGroupChannels}   = timeUnits;
   end
   
   % Create Ultimate load and Fixed mean load entries
   if (hasUltimate)
      tableData{unitsRow+1, 4:3+nGroupChannels} = l_ult;
   end
   if (hasFixedMean)
      tableData{unitsRow+2, 4:3+nGroupChannels} = lmf;
   end
   
   % Create m labels
   tableData{firstDataRow:firstDataRow+nDataRows-1,2} = slopes;
   
   % Create filenames column
   tableData{firstDataRow:firstDataRow+nDataRows-1,3} = files;
   
   % Create Mean wind speed column
   tableData{firstDataRow:firstDataRow+nDataRows-1,4+nGroupChannels} = meanWindspeeds;
   
   % Create Elapsed time column
   tableData{firstDataRow:firstDataRow+nDataRows-1,5+nGroupChannels} = elaspedTime;
   
   % Create # of datapoints in file column
   tableData{firstDataRow:firstDataRow+nDataRows-1,6+nGroupChannels} = dataPoints;
   
   % Create # of equivalent cycles in files column
   tableData{firstDataRow:firstDataRow+nDataRows-1,7+nGroupChannels} = equivCycles;
   
   % Create data
   tableData{firstDataRow:firstDataRow+nDataRows-1,4:3+nGroupChannels} = data;
   
   
   tableData.setColumnFormat(4:4+nGroupChannels,FileInfo.RealFmt);
   tableData.setColumnTextAlignment('c')
   
end