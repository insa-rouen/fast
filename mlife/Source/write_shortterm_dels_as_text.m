 function write_shortterm_dels_as_text( progName, outputFilename, FileInfo, Fatigue, windChannelMeans )
   
 
   % Write del predictions to a text file.

   % Open output file.  
   
   
   fprintf( '    Writing short-term damage equivalent load estimates to:\n' ); 
   fprintf( '      %s\n', outputFilename );
   
   fid = fopen( outputFilename, 'wt' );
   if ( fid < 0 )
      beep
      error( '  Could not open "%s" for writing.', outputFilename );
   end
   
   % Set up the header.
   what = 'These short-term damage equivalent load estimates';
   header = generate_text_header(progName, what);    
   fprintf( fid, '\n%s\n', header );
   
   
   nChannels    = size( Fatigue.ChanInfo , 2 );
   channelNames = cell(1, nChannels);
  
   
   for i=1:nChannels
      channelNames{i} = FileInfo.Names{Fatigue.ChanInfo(i).Chan};
   end
   %data = [Fatigue.File(iFile).DEL_FixedMean(:), Fatigue.File(iFile).DEL_ZeroMean(:), Fatigue.File(iFile).DEL_RangeOnly(:)];
   
   if ( Fatigue.DEL_AsRange )
      fprintf( fid, 'Damage equivalent loads are given as peak-to-valley ranges.\n');
   else
      fprintf( fid, 'Damage equivalent loads are given as one-sided amplitudes.\n');
     % data = data / 2.0;
   end
   fprintf( fid, '\n' );
   
   
   for iGroup = 1:Fatigue.nGroups
      if ( Fatigue.GoodmanFlag == 1 ||  Fatigue.GoodmanFlag == 2)
         if ( Fatigue.DEL_Type == 1 || Fatigue.DEL_Type == 3 )
            fixedMeanDELs = create_shortterm_text_table(iGroup, 1, Fatigue, FileInfo, windChannelMeans);
            fprintf( fid, '%s  Short-term DELs at Fixed Mean for various S/N Curves\n', char(Fatigue.Groups(iGroup).name) );
            fixedMeanDELs.toText(fid, 'delimiter','');
            fprintf( fid, '\n' );

         end
         if ( Fatigue.DEL_Type == 2 || Fatigue.DEL_Type == 3 )
            zeroMeanDELs = create_shortterm_text_table(iGroup, 2, Fatigue, FileInfo, windChannelMeans);
            fprintf( fid, '%s  Short-term DELs at Zero Mean for various S/N Curves\n', char(Fatigue.Groups(iGroup).name) );
            zeroMeanDELs.toText(fid, 'delimiter','');
            fprintf( fid, '\n' );
         end
      end
      if ( Fatigue.GoodmanFlag == 0 ||  Fatigue.GoodmanFlag == 2)
         noGoodmanDELs = create_shortterm_text_table(iGroup, 3, Fatigue, FileInfo, windChannelMeans);
         fprintf( fid, '%s  Short-term DELs without Goodman Correction for various S/N Curves\n', char(Fatigue.Groups(iGroup).name) );
         noGoodmanDELs.toText(fid, 'delimiter','');
         fprintf( fid, '\n' );
      end
   end

   fclose( fid );
 
     
end % function write_del_results_as_text(...)