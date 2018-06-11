function tableData = create_lifetime_table(iGroup, quantityType, Fatigue, FileInfo)

      nGroupChannels  = length(Fatigue.Groups(iGroup).channelIndices);
      channelNames    = cell(1,  nGroupChannels);
      l_ult           = zeros(1, nGroupChannels);
      
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
         l_ult(iCh)           = Fatigue.ChanInfo(Fatigue.Groups(iGroup).channelIndices(iCh)).LUlt;
         
         if( quantityType == 1 )
               lmf(iCh)             = Fatigue.ChanInfo(Fatigue.Groups(iGroup).channelIndices(iCh)).LMF;
         end
               
         
      end
      
      allSlopes      = Fatigue.Groups(iGroup).allSNSlopes;
      nGroupSlopes   = length(allSlopes);
      nDataRows      =  nGroupSlopes;
      data           = cell(nDataRows, nGroupChannels);
      
      slopes         = zeros(nDataRows,1);
      
      for iCh=1:nGroupChannels
        
            nSlopes = Fatigue.ChanInfo(Fatigue.Groups(iGroup).channelIndices(iCh)).NSlopes;
            for j=1:nSlopes
               iSlope = find((Fatigue.Groups(iGroup).allSNSlopes == Fatigue.ChanInfo(Fatigue.Groups(iGroup).channelIndices(iCh)).SNslopes(j)) > 0);
               %iSlope = Fatigue.Groups(iGroup).SNSlopeMap(Fatigue.ChanInfo(Fatigue.Groups(iGroup).channelIndices(iCh)).SNslopes(j));
               rowOffset = iSlope; %(j-1)*nSlopes ;
               slopes(rowOffset)         = Fatigue.ChanInfo(Fatigue.Groups(iGroup).channelIndices(iCh)).SNslopes(j);
               
                  
               
                  switch quantityType
                     case 1 % fixed mean DEL
                        dataValue = Fatigue.Channel(Fatigue.Groups(iGroup).channelIndices(iCh)).lifetimeDEL_FixedMeans(j);
                     case 2 % zero mean DEL
                        dataValue = Fatigue.Channel(Fatigue.Groups(iGroup).channelIndices(iCh)).lifetimeDEL_ZeroMeans(j);
                     case 3 % no goodman correction DEL
                        dataValue = Fatigue.Channel(Fatigue.Groups(iGroup).channelIndices(iCh)).lifetimeDEL_NoGoodman(j);
                     case 4 % damage with goodman
                        dataValue = Fatigue.Channel(Fatigue.Groups(iGroup).channelIndices(iCh)).lifetimeDamage(j);
                     case 5 % time until failure with goodman
                        dataValue = Fatigue.Channel(Fatigue.Groups(iGroup).channelIndices(iCh)).timeUntilFailure(j);
                     case 6 %  damage  without goodman
                        dataValue = Fatigue.Channel(Fatigue.Groups(iGroup).channelIndices(iCh)).lifetimeDamage_NoGoodman(j);
                     case 7 %  time until failure  without goodman
                        dataValue = Fatigue.Channel(Fatigue.Groups(iGroup).channelIndices(iCh)).timeUntilFailure_NoGoodman(j);
                  end
               
                  
               % if quantityType = 1, 2, 3 then this is a DEL, otherwise it is not
               if ( Fatigue.DEL_AsRange || quantityType > 3)
                  data{rowOffset,iCh} = dataValue;                
               else
                  data{rowOffset,iCh} = dataValue / 2.0;
               end
            end  % for j
         
      end % for iCh
      
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

   tableData{1,2} = {'m'};
   tableData{1,3:2+nGroupChannels} = channelNames;
  
   % Create units row
    if (FileInfo.HaveUnits)
       tableData{2,3:2+nGroupChannels} = channelUnits;

    end
   
   % Create Ultimate load and Fixed mean load entries
   if (hasUltimate)
      tableData{unitsRow+1, 3:2+nGroupChannels} = l_ult;
   end
   if (hasFixedMean)
      tableData{unitsRow+2, 3:2+nGroupChannels} = lmf;
   end
   
   % Create m labels
   tableData{firstDataRow:firstDataRow+nDataRows-1,2} = slopes;
   
   % Create filenames column
   %tableData{firstDataRow:firstDataRow+nDataRows-1,3} = files;
   
   
   % Create data
   tableData{firstDataRow:firstDataRow+nDataRows-1,3:2+nGroupChannels} = data;
   
   
   tableData.setColumnFormat(3:2+nGroupChannels,FileInfo.RealFmt);
   tableData.setColumnTextAlignment('c')
   
end