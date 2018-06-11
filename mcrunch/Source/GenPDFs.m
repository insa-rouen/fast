function GenPDFs( SettingsFile )
% Generate probability-density functions.
%
% It does this for the data in individual files and for the aggregate of
% all the files.
%
% Syntax is:  GenPDFs( SettingsFile )
%
%     where:
%        SettingsFile: A string array containing the name of the MCrunch settings
%                      file use for this analysis.
%
% Example:
%     GenPDFs( 'MySettings.mcru' )
%
% See also DelFile, DelSheet1, GetRoot, MCrunch, ReadSettings

   global AggRoot FileInfo PDF ProgName RealFmt StrFmt

   NumBins  = double( PDF.NumBins );
   NumChans = size( PDF.Chans, 2 );
   NumFiles = size( FileInfo.FileName, 1 );


      % Find the global minima, maxima, and ranges.

   %fprintf( '  Calculating global mimina, maxima, and ranges for PDFs.\n' );

   Minima = zeros( 1, NumChans ) + inf;
   Maxima = zeros( 1, NumChans ) - inf;

   for File=1:size( FileInfo.FileName, 1 )
      Minima = min( Minima, min( FileInfo.Time(:,PDF.Chans) ) );
      Maxima = max( Maxima, max( FileInfo.Time(:,PDF.Chans) ) );
   end % for File

   Range = Maxima - Minima;


      % Generate global PDF bins and set the outer limits of the bins table to +/- infinity so we don't have precision problems.

   PDF.PDFs                      =  zeros(NumBins  ,NumChans,NumFiles);
   PDF.Bins                      =  zeros(NumBins+1,NumChans);
   PDF.Bins(        1,1:NumChans) = -inf;
   PDF.Bins(NumBins+1,1:NumChans) =  inf;

   if ( NumFiles > 1 )
      PDF.AggPDFs = zeros( NumBins, 1 );
   end % if

   fprintf( '\n' );


      % Fill the bin tables.  Check for constant data and zero data.

   BinDeltas = zeros( 1, NumChans );

   for Ch=1:NumChans

      if ( Range(1,Ch) <= realmin )

         if ( abs( Minima(1,Ch) ) <= realmin )                         % Constant zeros. Make the limits ~ -NumBins/2 and NumBins/2.
            Range(1,Ch)     = NumBins;
            Minima(1,Ch)    = -NumBins/2;
            BinDeltas(1,Ch) = 1;

         else                                                           % Constant nonzeros. Make the limits ~ Minima-|Minima|/2 and Minima+|Minima|/2 (one of the two should be zero).

            Range(1,Ch)     = 2*Minima(1,Ch);
            Minima(1,Ch)    = Minima(1,Ch) - abs( Minima(1,Ch) );
            BinDeltas(1,Ch) = Range(1,Ch)/NumBins;

         end % if

         PDF.Bins(2:NumBins,Ch) = Minima(1,Ch) + (1:NumBins-1)';

      else


            % Create the bins for non-constant data.

         BinDeltas(1,Ch)        = Range(1,Ch)/NumBins;
         PDF.Bins(2:NumBins,Ch) = repmat( Minima(1,Ch), NumBins-1, 1) + (1:NumBins-1)'*BinDeltas(1,Ch);

      end % if

   end % for Chan


      % Generate PDFs for each file and the aggregate of all files.

   for File=1:NumFiles+1

      if ( File == NumFiles+1 )
         fprintf( '  Generating aggregate PDFs.\n' );
         NumLines = double( FileInfo.TotLines );
         RowRange = 1:NumLines;
      else
         fprintf( '  Generating PDFs for "%s".\n', FileInfo.FileName{File} );
         NumLines = double( FileInfo.NumLines(File) );
         RowRange = FileInfo.StartLine(File) : ( FileInfo.StartLine(File) + NumLines - 1 );
      end % if


         % Compute the histograms and normalize them so the values are independent of the number of bins.

      PDFs = zeros( NumBins+1, NumChans );

      for Ch=1:NumChans
         PDFs(:,Ch) = histc( FileInfo.Time(RowRange,PDF.Chans(Ch)), PDF.Bins(:,Ch) )/( BinDeltas(1,Ch)*NumLines );
      end % for Ch


         % Move points from the extra bin at the end to the last kept bin.

      PDFs(NumBins,:) = PDFs(NumBins,:) + PDFs(NumBins+1,:);

      if ( File == NumFiles+1 )
         PDF.AggPDFs    = PDFs(1:NumBins,:);
      else
         PDF.PDFs(1:NumBins,:,File) = PDFs(1:NumBins,:);
      end % if

   end % for File


      % Repair Bins array by replacing the first bin with the minima and eliminating the extra bin.
      % Report the PDFs at the bin centers, so add half the bin width to each bin location.

   PDF.Bins      = PDF.Bins(1:NumBins,:) + 0.5*repmat( BinDeltas(1,:), NumBins, 1 );
   PDF.Bins(1,:) = Minima(:)' + 0.5*BinDeltas(1,:);


      % Write PDFs to a plain-text file?

   if ( PDF.WrTxt )
      WrTxt;
   end % if


      % Write PDFs to a plain-text file?

   if ( PDF.WrXLS )
      WrXLS
   end % if


      % Plot the results?

   if ( ~isempty( PDF.Plots ) )
      GenPDFPlots;
   end % if


   return
%===============================================================================
   function GenPDFPlots
   % Syntax: GenPDFPlots

      global ChartPosition LineWidth PlotColors SaveFigs

      PlotColors = [ 'r', 'b', 'c', 'm', 'g', 'k', 'y', 'w' ];

      fprintf( '  Generating PDF plots.\n' );


         % Plot the figure(s).

      for Fig=1:size( PDF.Plots, 2 )


            % Create a temporary figure that holds the title, which is generated by the text() function.
            % Save the size of the title for creation later.  THis gets around a problem that sometimes
            %  the title() function wraps the text.

         HdlFig = figure( 20000+Fig );
         close( HdlFig );
         HdlFig = figure( 20000+Fig );
         set( HdlFig, 'Position', ChartPosition );
         Title  = [ 'Probability Density Plots of ', PDF.Plots(Fig).Name ];
         HdlTxt = text( 0, 0, Title, 'FontName','Trebuchet MS', 'FontSize',16, 'FontWeight','bold', 'Units','normalized' );
         TitPos = get( HdlTxt, 'extent' );
         close( HdlFig );


            % Create the permanent figure.

         HdlFig = figure( 20000+Fig );

         set( HdlFig, 'Position', ChartPosition );
         set( HdlFig, 'Color',[1 1 1], 'name',Title, 'NumberTitle','off', 'PaperOrientation','landscape', 'PaperPosition',[0.25 0.25 10.5 8.0], 'PaperType','usletter' );


            % Add an overall title that is centered at the top of the figure.

         HdlTit = annotation('textbox', 'String',Title, 'FontName','Trebuchet MS', 'FontSize',16, 'FontWeight','bold' );
         set( HdlTit, 'Color', [0.0, 0.0, 1.0 ], 'LineStyle','none' );
         set( HdlTit, 'Units','normalized', 'HorizontalAlignment','center', 'VerticalAlignment','top' );
         set( HdlTit, 'Position', [ 0.5*(1-TitPos(3)), 1-TitPos(4), TitPos(3), TitPos(4) ] )

         TitPos = get( HdlTit, 'position' );


            % Generate the subplots.

         NumSp = size( PDF.Plots(Fig).Chans, 2 );
         HdlSP = zeros( NumSp );

         for SP=1:NumSp

            ACh = PDF.Plots(Fig).Chans(SP);
            Ind = PDF.Plots(Fig).ChanInd(SP);

            HdlSP(SP) = subplot( PDF.Plots(Fig).NRows, PDF.Plots(Fig).NCols, SP );


               % Add curve for each PDF, including the aggregate, to the plot.

            for File=1:size( FileInfo.FileName, 1 )
               Color = PlotColors( mod( File-1, 5 ) + 1 );
               plot( PDF.Bins(:,Ind), PDF.PDFs(:,Ind,File), Color, 'LineWidth', LineWidth );
               hold on;
            end % for File

            if ( size( PDF.Plots, 2 ) )
               plot( PDF.Bins(:,Ind), PDF.AggPDFs(:,Ind), 'k', 'LineWidth', LineWidth );
            end % if

            hold off


               % Label it and make it pretty.

            set( gca, 'FontName','Trebuchet MS', 'FontSize',11, 'FontWeight','bold', 'LineWidth',1.2, 'XColor',[0 0 0], 'YColor',[0 0 0] );
            grid on;

            if ( FileInfo.HaveNames )
               if ( FileInfo.HaveUnits )
                  xlabel( [FileInfo.Names{ACh},' ',FileInfo.Units{ACh}], 'FontName','Trebuchet MS', 'FontSize',14, 'FontWeight','bold' );
               else
                  xlabel( FileInfo.Names{ACh}, 'FontName','Trebuchet MS', 'FontSize',14, 'FontWeight','bold' );
               end % if
            end % if

            if ( FileInfo.HaveUnits )
               ylabel( ['PDF, ',FileInfo.Units{ACh},'^-^1'], 'FontName','Trebuchet MS', 'FontSize',14, 'FontWeight','bold' );
            else
               ylabel( 'PDF', 'FontName','Trebuchet MS', 'FontSize',14, 'FontWeight','bold' );
            end % if

         end % for SP


            % Create the legend and put it at the top-center of the figure.

         if ( size( FileInfo.FileName, 1 ) > 1 )
            HdlLeg = legend( [ FileInfo.FileName; 'Aggregate' ], 'interpreter','none', 'FontSize',7, 'location','NorthOutside' );
            set( HdlLeg, 'Units','normalized' );
            LPos = get( HdlLeg, 'position' );
            set( HdlLeg, 'Position', [ (1-LPos(3))/2, 1-TitPos(4)-LPos(4), LPos(3), LPos(4) ] );
            LPos = get( HdlLeg, 'Position' );
         else
            LPos = zeros( 4, 1 );
         end % if


            % Resize the subplots so the legend doesn't cover any of them.

         SPht = ( 1.0 - LPos(4) - TitPos(4) - 0.03 )/PDF.Plots(Fig).NRows - 0.1;

         for Row=1:PDF.Plots(Fig).NRows
            for Col=1:PDF.Plots(Fig).NCols
               SP    = ( Row - 1 )*PDF.Plots(Fig).NCols + Col;
               SPpos = get( HdlSP(SP), 'position' );
               Yloc  = 0.1 + ( PDF.Plots(Fig).NRows - Row )*( SPht + 0.1 );
               set( HdlSP(SP), 'position', [ SPpos(1), Yloc, SPpos(3), SPht ] );
            end % for Col
         end % for Row

         if ( SaveFigs )
            saveas( HdlFig, [ Title, '.fig' ] )
         end % if

      end % for Fig


      return

   end % function GenPDFPlots
%===============================================================================
   function WrTxt
   % This function writes the PDFs to plain-text files.

      DateTime = clock;
      Date     = date;


         % Generate a text file for each data file.  File "0" is for the aggregate.

      for File=0:NumFiles


            % There is no aggregate if there is only one file.

         if ( ( File == 0 ) && ( NumFiles == 1 ) )
            continue
         end % if


          % Set up the name of the text file.

         if ( File == 0 )
            TxtFile = [ AggRoot, '.pdfs' ];
            fprintf( '  Writing aggregate PDFs to plain-text file, "%s".\n', TxtFile );
         else
            TxtFile = [ GetRoot( FileInfo.FileName{File} ), '.pdfs' ];
            fprintf( '  Writing PDFs to plain-text file, "%s".\n', TxtFile );
         end % if


            % Open the text file and add a header.

         fid = fopen( TxtFile, 'wt' );
         
         while ( fid < 0 )
            beep;
            button = questdlg( sprintf( 'Unable to open  "%s" for writing. Please check file permissions or if file is in use by another program.', TxtFile ), 'File Locked!', 'retry', 'abort', 1);
            if(button == 'abort')
               break;
            end
         
            fid = fopen( TxtFile, 'wt' );
         end % while

         if ( File == 0 )

            fprintf( fid, '\nThese aggregate probability densities were generated by %s on %s at %02d:%02d:%02d.\n', ProgName, Date, uint8( DateTime(4:6) ) );
            fprintf( fid, '\nThe analysis was based upon %d rows from an aggregate of %d files.\n\n',  FileInfo.TotLines, NumFiles );
            for iCh=1:NumChans
               fprintf( fid,  [ StrFmt, '-x', StrFmt, '-y' ], FileInfo.Names{PDF.Chans(iCh)},'PDF' );
            end
            fprintf( fid, '\n');
            
            for Bin=1:NumBins
               fprintf( fid, [ repmat( [ '  ', RealFmt ], 1, 2*NumChans ), '\n' ], [ PDF.Bins(Bin,:); PDF.AggPDFs(Bin,:) ] );
            end % for Bin

         else

            fprintf( fid, '\nThese probability densities from %s were generated by %s on %s at %02d:%02d:%02d.\n', FileInfo.FileName{File}, ProgName, Date, uint8( DateTime(4:6) ) );
            fprintf( fid, '\nThe analysis was based upon %d rows.\n\n',  FileInfo.NumLines(File) );
            for iCh=1:NumChans
               fprintf( fid,  [ StrFmt, '-x', StrFmt, '-y' ], FileInfo.Names{PDF.Chans(iCh)},'PDF' );
            end
            fprintf( fid, '\n');
            % the following line creates (bin value, channel PDF) pairs for
            % each channel
            for Bin=1:NumBins
               fprintf( fid, [ repmat( [ '  ', RealFmt ], 1, 2*NumChans ), '\n' ], [ PDF.Bins(Bin,:); PDF.PDFs(Bin,:,File) ] );
            end % for Bin

         end % if

         fclose( fid );

      end % for File

      return

   end % function WrTxt
   %===============================================================================
   function WrXLS
   % Write the PDFs to an Excel workbook.


         % Set up the name of the Excel file.  Delete the file if it already exists

      XLSfile = [ GetRoot( SettingsFile ), '_PDFs.xls' ];

      fprintf( '  Writing probability densities to Excel workbook, "%s":\n', XLSfile );

      DelFile( XLSfile );


         % Turn off warnings regarding adding sheets to the workbook.

      warning off MATLAB:xlswrite:AddSheet


         % Get date and time.

      DateTime = clock;
      Date     = date;


         % Set up a cell array to hold the information for the various sheets.

      Info = cell( NumBins+6, 2*NumChans );


         % Generate a sheet for each data file.  File=0 is for the aggregate.

      for File=0:NumFiles


            % There is no aggregate if there was only one file.

         if ( ( File == 0 ) && ( NumFiles == 1 ) )
            continue
         end % if


            % Set up the name of the sheets.  Generate the header.

         if ( File == 0 )
            Sheet   ='Aggregate';
            Info{2,1} = sprintf( 'These aggregate probability densities were generated by %s on %s at %02d:%02d:%02d.', ProgName, Date, uint8( DateTime(4:6) ) );
            Info{4,1} = sprintf( 'The analysis was based upon %d rows from an aggregate of %d files.',  FileInfo.TotLines, NumFiles );
         else
            Sheet = GetRoot( FileInfo.FileName{File} );
            Info{2,1} = sprintf( 'These probability densities were generated by %s on %s at %02d:%02d:%02d.', ProgName, Date, uint8( DateTime(4:6) ) );
            Info{4,1} = sprintf( 'The analysis was based upon %d rows.',  FileInfo.NumLines(File) );
         end % if

         fprintf( '    %s\n', Sheet );


            % Add column headings and data to cell array.

         for Ch=1:NumChans

            Col = 2*Ch - 1;
            PCh = PDF.Chans(Ch);

            Info{6,Col  }   = [ FileInfo.Names{PCh}, '-x' ];
            Info{6,Col+1}   = 'PDF-y';
            Info(7:end,Col) = mat2cell( PDF.Bins(:,Ch), repmat(1,NumBins,1), 1 );

            if ( File == 0 )
               Info(7:end,Col+1) = mat2cell( PDF.AggPDFs(:,Ch), repmat(1,NumBins,1), 1 );
            else
               Info(7:end,Col+1) = mat2cell( PDF.PDFs(:,Ch,File), repmat(1,NumBins,1), 1 );
            end % if

         end % for Ch


            % Add data to the proper sheet in the workbook.

         xlswrite( XLSfile, Info, Sheet, 'A1' );

      end % for File


         % Delete the blank sheet, "Sheet1".

      DelSheet1( XLSfile );

      return

   end % function WrXLS
%===============================================================================

end % function GenPDFs( SettingsFile )
