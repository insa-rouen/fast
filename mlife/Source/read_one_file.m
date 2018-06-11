function [timeSeriesData, nLines, title] = read_one_file(file, fileFormat, titleLine, firstDataLine, names, doScaleData, scales, offsets, CalcChan, LoadRoses, DLCs, PSFtype )
% Read one data file.
%
% where:
%
%     file           - filename of input data
%     fileFormat       - format of input file.  1 = ascii, 2 = binary
%     titleLine      - line containing title information
%     firstDataLine  - line containing first row of data
%     names          - cell array (1 x nChannels) of channel names
%     doScaleData    - boolean true = transform the data based on y = x*scale + offset
%     scales         - gain values for data transformation
%     offset         - offset values for data transformation
%     CalcChan       - structure array (1 x nCalcChannels) of calculated channel information
%     LoadRoses      - structure array (1 x nLoadRosesChannels) of load rose channel information
%     DLCs           - array of number of files in each DLC
%     PSFtype        - array containing the scale factors for each partial safety factor type on a per DLC-type basis
%
%  returns:
%     title          - title string for this input file
%     nLines         - number of data lines in the file
%     timeSeriesData - a matrix of data with nLines x nChannels rows, columns

% Example:
%     [timeSeriesData, nLines, title] = read_one_file('myInputs.dat', 5, 9, names, 0, 0, 0, CalcChan )
%
% Called by: mlife



   
   title = '';

      % How many calculated channels do we have?
   NumCC = size( CalcChan, 2 );

      % How many load roses channels do we have?
   NumLRC     = 0;
   nLoadRoses = size( LoadRoses, 2 );
   for iRose=1:nLoadRoses
      NumLRC  = NumLRC + LoadRoses(iRose).nSectors;
   end

   
      % get the total number of bytes.

   Info = dir( file );

   if ( size( Info, 1 ) == 0 )
      beep
      error( '    Could not open "%s" for reading.', file );
   end

   FileSize = Info.bytes;

      % number of channels including calculated channels
   NumCols = size( names, 2 );
   
      % number of channels without including calculated channels
   NumIC   = NumCols - NumCC - NumLRC;
   
      
   if ( fileFormat == 2 ) % the file is binary format
      
      [timeSeriesData, ~, ~, ~] = ReadFASTbinary(file);
      title = '';   
      
   else % the file is ascii format
              
      fid = fopen( file, 'rt' );

      if ( fid < 0 )
         beep
         error( '    Could not open "%s" for reading.', file );
      end

      fprintf( '    Reading "%s" (%f MB).\n', file, FileSize/1024^2 );


         % Get the title line from header.  Store the starting line number for this file.

      HeadLines = textscan( fid, '%s', firstDataLine-1, 'delimiter', '\n' );

      if ( titleLine > 0 )
         title = HeadLines{1}{titleLine};
      else
         title = ''; 
      end % if


         % Read the numeric data and store it in the time-series matrix.

      temp = textscan(fid,repmat('%f ',1,NumIC),'CollectOutput',1);
      timeSeriesData = temp{1};
      

         % Close the data file.

      fclose ( fid );
      
   end % if fileFormat
      
   
   if ( size( timeSeriesData, 2 ) ~= NumIC )
      beep
      error( [ '  Do you have white space in any of your channel names?  The number', ...
                        '  of channels expected differs from what is in the first file.' ] );
   end % if

   nLines = size( timeSeriesData, 1 );
   fprintf( '      Rows=%d, Cols=%d\n', nLines, NumCols );


      % If we specified the channel information in the parameter input file, we may need scales and offsets.
      % If the channel names came from the data files, we do not have that option.

   if ( doScaleData )

      timeSeriesData(:,1:NumIC) = repmat(scales,nLines,1).*timeSeriesData(:,1:NumIC) + repmat(offsets,nLines,1);
      posPSF =  PSFtype > 0 ;
      if (sum(posPSF) > 0 )
         timeSeriesData(:,posPSF) = timeSeriesData(:,posPSF) .* repmat(DLCs.PSF(PSFtype(posPSF)),nLines,1);
      end

   end % if doScaleData

   
      % Add the calculated-channel data.

   for Chan=1:NumCC
      timeSeriesData(:,NumIC+Chan) = eval( CalcChan(Chan).Eqn );
   end % for

   
      % Add Load Roses channels
      
   iChan = 1;
   for iRose=1:nLoadRoses
      
      for iSector=1:LoadRoses(iRose).nSectors
         
         theta                               = (iSector - 0.5)*pi / LoadRoses(iRose).nSectors;
         timeSeriesData(:,NumIC+NumCC+iChan) = cos(theta)*timeSeriesData(:,LoadRoses(iRose).Channel1) + ...
                                               sin(theta)*timeSeriesData(:,LoadRoses(iRose).Channel2);
         iChan                               = iChan + 1;
         
      end % for iSector
      
   end % for iRose
      
   
      % Delete the unused rows from the time series.

   timeSeriesData((nLines+1):size(timeSeriesData,1),:) = [];


   fprintf( '      Done reading\n' );

   return

end % function ReadManyFiles
