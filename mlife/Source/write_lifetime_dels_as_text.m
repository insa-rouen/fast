 function write_lifetime_dels_as_text( progName, outputFilename, FileInfo, Fatigue )
   
   outputFilename = [outputFilename '_Lifetime_DELs.txt'];
    
   % Write del predictions to a text file.

   % Open output file.  
   
   
   fprintf( '    Writing lifetime damage equivalent load estimates to:\n' ); 
   fprintf( '      %s\n', outputFilename );
   
   fid = fopen( outputFilename, 'wt' );
   if ( fid < 0 )
      beep
      error( '  Could not open "%s" for writing.', outputFilename );
   end
   
   % Set up the header.
   what = 'These lifetime damage equivalent load estimates';
   header = generate_text_header(progName, what);    
   fprintf( fid, '\n%s\n', header );
   
   
   nChannels    = size( Fatigue.ChanInfo , 2 );
   channelNames = cell(1, nChannels);
  
   for i=1:nChannels
      channelNames{i} = FileInfo.Names{Fatigue.ChanInfo(i).Chan};
   end
   %data = [Fatigue.File(iFile).DEL_FixedMean(:), Fatigue.File(iFile).DEL_ZeroMean(:), Fatigue.File(iFile).DEL_RangeOnly(:)];
   
   if ( Fatigue.DEL_AsRange )
      fprintf( fid, 'Damage equivalent loads are given as peak-to-valley ranges.\n\n');
   else
      fprintf( fid, 'Damage equivalent loads are given as one-sided amplitudes.\n\n');
     % data = data / 2.0;
   end
   
   
   
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   % Write out general information
   fprintf( fid, 'A total of %d samples across %d files.\n\n',sum(FileInfo.nSamples(:)),FileInfo.nFiles);
   
   lifetimeTable = create_lifetime_header_table( FileInfo, Fatigue );
   weibullTable  = create_weibull_table( Fatigue );

   lifetimeTable.toText( fid, 'delimiter', '' );
   fprintf( fid, '\n' );
   fprintf( fid, 'Weibull Wind Speed Distribution Properties' );
   weibullTable.toText( fid, 'delimiter', '' );
   fprintf( fid, '\n\n\n' );
   
   
   for iGroup = 1:Fatigue.nGroups
     if ( Fatigue.GoodmanFlag == 1 ||  Fatigue.GoodmanFlag == 2)
         if ( Fatigue.DEL_Type == 1 || Fatigue.DEL_Type == 3 )
            fixedMeanDELs = create_lifetime_table(iGroup, 1, Fatigue, FileInfo);
            fprintf( fid, '%s  Lifetime DELs at Fixed Mean for various S/N Curves\n', char(Fatigue.Groups(iGroup).name) );
            fixedMeanDELs.toText(fid, 'delimiter','');
            fprintf( fid, '\n' );

         end
         if ( Fatigue.DEL_Type == 2 || Fatigue.DEL_Type == 3 )
            zeroMeanDELs = create_lifetime_table(iGroup, 2, Fatigue, FileInfo);
            fprintf( fid, '%s  Lifetime DELs at Zero Mean for various S/N Curves\n', char(Fatigue.Groups(iGroup).name) );
            zeroMeanDELs.toText(fid, 'delimiter','');
            fprintf( fid, '\n' );
         end
      end
      if ( Fatigue.GoodmanFlag == 0 ||  Fatigue.GoodmanFlag == 2)
         noGoodmanDELs = create_lifetime_table(iGroup, 3, Fatigue, FileInfo);
         fprintf( fid, '%s  Lifetime DELs without Goodman Correction for various S/N Curves\n', char(Fatigue.Groups(iGroup).name) );
         noGoodmanDELs.toText(fid, 'delimiter','');
         fprintf( fid, '\n' );
      end
   end


   

   fclose( fid );
     
end % function write_lifetime_dels_as_text(...)