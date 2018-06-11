function GenTimePlots( SubPlots )
% Generate time-series plots of data.
%
% The data is stored in the FileInfo structure.
%
% Syntax: GenTimePlots( SubPlots )
%
%     where:

%        SubPlots:   A structure containing details about how to generate one
%                    or more figures containing one or more subplots.
%
%        The SubPlots structure must have the following format:
%
%          SubPlots(Fig).Name  - A name to be used for the figure and window title.
%          SubPlots(Fig).NRows - The number of subplot rows in the given figure.
%          SubPlots(Fig).NCols - The number of subplot columns in the given figure.
%          SubPlots(Fig).Chans - The list of channels to be plotted in the subplots.
%
% Example:
%     GenTimePlots( TimePlotStructure )
%
% See also MCrunch, ReadSettings

   global FileInfo PlotColors LineWidth ChartPosition SaveFigs

   PlotColors = [ 'r', 'b', 'c', 'm', 'g', 'k', 'y', 'w' ];

   fprintf( '  Generating time-series plots.\n' );


      % Plot the figure(s).

   for Fig=1:size( SubPlots, 2 )


         % Create a temporary figure that holds the title, which is generated by the text() function.
         % Save the size of the title for creation later.  This gets around a problem that sometimes
         %  the title() function wraps the text.

      HdlFig = figure( 30000+Fig );
      close( HdlFig );
      HdlFig = figure( 30000+Fig );
      set( HdlFig, 'Position', ChartPosition );
      Title  = [ 'Time Series Plots of ', SubPlots(Fig).Name ];
      HdlTxt = text( 0, 0, Title, 'FontName','Trebuchet MS', 'FontSize',16, 'FontWeight','bold', 'Units','normalized' );
      TitPos = get( HdlTxt, 'extent' );
      close( HdlFig );


         % Create the permanent figure.

      HdlFig = figure( 30000+Fig );

      set( HdlFig, 'Position', ChartPosition );
      set( HdlFig, 'Color',[1 1 1], 'name',Title, 'NumberTitle','off', 'PaperOrientation','landscape', 'PaperPosition',[0.25 0.25 10.5 8.0], 'PaperType','usletter' );


         % Add an overall title that is centered at the top of the figure.

      HdlTit = annotation('textbox', 'String',Title, 'FontName','Trebuchet MS', 'FontSize',16, 'FontWeight','bold' );
      set( HdlTit, 'Color', [0.0, 0.0, 1.0 ], 'LineStyle','none' );
      set( HdlTit, 'Units','normalized', 'HorizontalAlignment','center', 'VerticalAlignment','top' );
      set( HdlTit, 'Position', [ 0.5*(1-TitPos(3)), 1-TitPos(4), TitPos(3), TitPos(4) ] )

      TitPos = get( HdlTit, 'position' );


         % Generate the subplots.

      NumSP = size( SubPlots(Fig).Chans, 2 );
      HdlSP = zeros( NumSP,1 );

      for SP=1:NumSP

         Col = SubPlots(Fig).Chans( SP );

         HdlSP(SP) = subplot( SubPlots(Fig).NRows, SubPlots(Fig).NCols, SP );


            % Add curve for each file to the plot.

         for File=1:size( FileInfo.StartLine, 1 )
            Color    = mod( File-1, 5 ) + 1;
            RowRange = FileInfo.StartLine(File) : ( FileInfo.StartLine(File) + FileInfo.NumLines(File) - 1 );
            plot( FileInfo.Time(RowRange,1), FileInfo.Time(RowRange,Col), PlotColors(Color), 'LineWidth', LineWidth );
            hold on;
         end % for File
         hold off


            % Label it and make it pretty.

         set( gca, 'FontName','Trebuchet MS', 'FontSize',11, 'FontWeight','bold', 'LineWidth',1.2, 'XColor',[0 0 0], 'YColor',[0 0 0] );
         grid on;
         if ( FileInfo.HaveNames )
            if ( FileInfo.HaveUnits )
               xlabel( [FileInfo.Names{1  },' ',FileInfo.Units{1  }], 'FontName','Trebuchet MS', 'FontSize',14, 'FontWeight','bold' );
               ylabel( [FileInfo.Names{Col},' ',FileInfo.Units{Col}], 'FontName','Trebuchet MS', 'FontSize',14, 'FontWeight','bold' );
            else
               xlabel( FileInfo.Names{1  }, 'FontName','Trebuchet MS', 'FontSize',14, 'FontWeight','bold' );
               ylabel( FileInfo.Names{Col}, 'FontName','Trebuchet MS', 'FontSize',14, 'FontWeight','bold' );
            end % if
         end % if

         set( HdlFig, 'Position', ChartPosition );

      end % for SP


         % Create the legend and put it at the top-center of the figure.

      if ( size( FileInfo.FileName, 1 ) > 1 )
         HdlLeg = legend( FileInfo.FileName, 'interpreter','none', 'FontSize',7, 'location', 'NorthOutside' );
         set( HdlLeg, 'Units','normalized' );
         LPos = get( HdlLeg, 'position' );
         set( HdlLeg, 'Position', [ (1-LPos(3))/2, 1-TitPos(4)-LPos(4), LPos(3), LPos(4) ] );
         LPos = get( HdlLeg, 'Position' );
      else
         LPos = zeros( 4, 1 );
      end % if


%         % Create the legend and put it at the top-center of the figure.
%
%      HdlLeg = legend( FileInfo.FileName, 'interpreter','none', 'FontSize',7, 'location', 'NorthOutside' );
%      LPos   = get( HdlLeg, 'outerposition' );
%      set( HdlLeg, 'outerposition', [ (1-LPos(3))/2, 1-LPos(4), LPos(3), LPos(4) ] );
%      LPos   = get( HdlLeg, 'outerposition' );


         % Resize the subplots so the legend doesn't cover any of them.

      SPht = ( 1.0 - LPos(4) - TitPos(4) - 0.03 )/SubPlots(Fig).NRows - 0.1;

      for Row=1:SubPlots(Fig).NRows
         for Col=1:SubPlots(Fig).NCols
            SP    = ( Row - 1 )*SubPlots(Fig).NCols + Col;
            SPpos = get( HdlSP(SP), 'position' );
            Yloc  = 0.1 + ( SubPlots(Fig).NRows - Row )*( SPht + 0.1 );
            set( HdlSP(SP), 'position', [ SPpos(1), Yloc, SPpos(3), SPht ] );
         end % for Col
      end % for Row

      if ( SaveFigs )
         saveas( HdlFig, [ Title, '.fig' ] )
      end % if

   end % for Fig

end % function GenTimePlots( SubPlots )