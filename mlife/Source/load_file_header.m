function [names, units] = load_file_header(fileName, fileFormat, namesLine, unitsLine, firstDataLine, autoNames, autoUnits, haveNames, haveUnits, CalcChan)
% Load information which is located in the data file's header lines and
% is common to all data files.
%
%
% Syntax is:  load_file_header(fileName, namesLine, unitsLine, CalcChan);
%
%     where:
%        fileName       - A cell array containing a file name.
%        fileFormat     - File format.  1 = ascii, 2 = binary
%        namesLine      - A double scalar telling the number of the line that contains the
%                         channel names.  Set to zero if there is none.
%        unitsLine      - A double scalar telling the number of the line that contains the
%                         channel units.  Set to zero if there is none.
%        firstDataLine  - line containing first of time series data
%        autoNames      - populate the names array by reading channel names from input file
%        autoUnits      - populate the units array by reading channel units from input file
%        haveNames      - names are to be read from file
%        haveUnits      - units are to be read from file
%        CalcChan       - A structure array containing information for generating calculated
%                         channels.  It must have the following format (all are strings):
%                              CalcChan(Chan).Name  - The calculated channel's name.
%                              CalcChan(Chan).units - The calculated channel's units.
%                              CalcChan(Chan).Eqn   - The calculated channel's equation.
% Example:
%     load_file_header('mydata_01.out', 4, 5, CalcChan);
%
% See also mlife

%   global FileInfo
   names = [];
   units = [];
   
   if ( fileFormat == 2 ) 
      
      [~, cellNames, cellUnits, ~] = ReadFASTbinary(fileName);
      
      if (autoUnits)            
         units = { cellUnits{:} };
      end 

      if ( autoNames )
         names = {cellNames{:}};
      end % if
  
   else
      
      fid = fopen(fileName, 'rt');
      if (fid < 0)
         beep
         error('  Could not open "%s" for reading.', fileName);
      end
         % read in the header lines
      headLines = textscan(fid, '%s', firstDataLine-1, 'delimiter', '\n');
      fclose(fid);
      
      if ( autoNames )
         cellNames      = textscan(headLines{1}{namesLine}, '%s');
         names = {cellNames{1}{:}};
         nColumns        = size(names, 2);
      end % if

      if (autoUnits)
         % GJH : TODO verify this does not have a possible bug when autoNames = false but autoUnits = true.  In that case nColumns is undefined!
         cellUnits      = textscan( headLines{1}{unitsLine}, '%s', nColumns);
         units = {cellUnits{1}{:}};
      end
      
   end % if fileFormat
   
   
  
   

  

   
      
       % How many calculated channels do we have?
   nCalculatedChannels = size(CalcChan, 2);

      % add calculated channel information
      
   if ((nCalculatedChannels > 0) && haveNames)
      names = {names{:}, CalcChan(:).Name};
   end 
   
   if ((nCalculatedChannels > 0) && haveUnits)
      units = {units{:}, CalcChan(:).Units};
   end 

end  % load_file_header