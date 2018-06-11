 function write_shortterm_damage_rate_as_text(progName, outputFilename, FileInfo, Fatigue, windChannelMeans)
   
 
   %[fieldWidth, ~, ~] = parse_format(realFmt);
   
   % Write del predictions to a text file.

   % Open output file.  
   
   
   fprintf( '    Writing short-term damage-rate estimates to:\n' ); 
   fprintf( '      %s\n', outputFilename );
   
   fid = fopen( outputFilename, 'wt' );
   if ( fid < 0 )
      beep
      error( '  Could not open "%s" for writing.', outputFilename );
   end
   
   % Set up the header.
   what = 'These short-term damage rate estimates';
   header = generate_text_header(progName, what);    
   fprintf( fid, '\n%s\n', header );
    
   nChannels    = size( Fatigue.ChanInfo , 2 );
   channelNames = cell(1, nChannels);
   
   for i=1:nChannels
      channelNames{i} = FileInfo.Names{Fatigue.ChanInfo(i).Chan};
   end
  
   
   for iGroup = 1:Fatigue.nGroups
      if ( Fatigue.GoodmanFlag == 1 ||  Fatigue.GoodmanFlag == 2)
         
            fixedMeanDELs = create_shortterm_text_table(iGroup, 4, Fatigue, FileInfo, windChannelMeans);
            fprintf( fid, '%s  Short-term Damage-rate (-/s) for various S/N Curves\n', char(Fatigue.Groups(iGroup).name) );
            fixedMeanDELs.toText(fid, 'delimiter','');
            fprintf( fid, '\n' );
       
         
      end
      if ( Fatigue.GoodmanFlag == 0 ||  Fatigue.GoodmanFlag == 2)
         noGoodmanDELs = create_shortterm_text_table(iGroup, 5, Fatigue, FileInfo, windChannelMeans);
         fprintf( fid, '%s  Short-term Damage-rate (-/s) without Goodman Correction for various S/N Curves\n', char(Fatigue.Groups(iGroup).name) );
         noGoodmanDELs.toText(fid, 'delimiter','');
         fprintf( fid, '\n' );
      end
   end

   fclose( fid );
  
     
end % function write_del_results_as_text(...)