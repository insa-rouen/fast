 function write_lifetime_damage_as_text( progName, outputFilename, FileInfo, Fatigue )
   
   outputFilename = [outputFilename '_Lifetime_Damage.txt'];
   
   % Write del predictions to a text file.

   % Open output file.  
   
   
   fprintf( '    Writing lifetime damage estimates to:\n' ); 
   fprintf( '      %s\n', outputFilename );
   
   fid = fopen( outputFilename, 'wt' );
   if ( fid < 0 )
      beep
      error( '  Could not open "%s" for writing.', outputFilename );
   end
   
   % Set up the header.
   what = 'These lifetime damage estimates';
   header = generate_text_header(progName, what);    
   fprintf( fid, '\n%s\n', header );
   
   
   nChannels    = size( Fatigue.ChanInfo , 2 );
   channelNames = cell(1, nChannels);
   
   for i=1:nChannels
      channelNames{i} = FileInfo.Names{Fatigue.ChanInfo(i).Chan};
   end
  
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   % Write out general information
   
   fprintf( fid, 'A total of %d samples across %d files.\n\n',sum(FileInfo.nSamples(:)),FileInfo.nFiles);
   
   weibullTable  = create_weibull_table( Fatigue );
   fprintf( fid, 'Weibull Wind Speed Distribution Properties' );
   weibullTable.toText( fid, 'delimiter', '' );
   fprintf( fid, '\n\n\n' );
  
   
   for iGroup = 1:Fatigue.nGroups
      if ( Fatigue.GoodmanFlag == 1 ||  Fatigue.GoodmanFlag == 2)
         
            lifetimeDamage = create_lifetime_table(iGroup, 4, Fatigue, FileInfo);
            timeUntilFailure = create_lifetime_table(iGroup, 5, Fatigue, FileInfo);
            
            fprintf( fid, '%s  Lifetime Damage (-) for various S/N Curves\n', char(Fatigue.Groups(iGroup).name) );
            lifetimeDamage.toText(fid, 'delimiter','');
            fprintf( fid, '\n' );
            
            fprintf( fid, '%s  Time Until Failure (s) for various S/N Curves\n', char(Fatigue.Groups(iGroup).name) );
            timeUntilFailure.toText(fid, 'delimiter','');
            fprintf( fid, '\n' );

        
         
      end
      if ( Fatigue.GoodmanFlag == 0 ||  Fatigue.GoodmanFlag == 2)
         lifetimeDamage = create_lifetime_table(iGroup, 6, Fatigue, FileInfo);
            timeUntilFailure = create_lifetime_table(iGroup, 7, Fatigue, FileInfo);
            
            fprintf( fid, '%s  Lifetime Damage (-) without Goodman Correction for various S/N Curves\n', char(Fatigue.Groups(iGroup).name) );
            lifetimeDamage.toText(fid, 'delimiter','');
            fprintf( fid, '\n' );
            
            fprintf( fid, '%s  Time Until Failure (s) without Goodman Correction for various S/N Curves\n', char(Fatigue.Groups(iGroup).name) );
            timeUntilFailure.toText(fid, 'delimiter','');
            fprintf( fid, '\n' );
      end
   end
   


   fclose( fid );
     
end % function write_lifetime_damage_as_text(...)