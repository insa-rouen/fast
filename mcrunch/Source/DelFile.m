function DelFile( File )
% Delete a file if it exists.  If open, warn user.
%
% Syntax is DelFile( File )
%
% Example:
%
%     DelFile( 'MyWorkBook.xls' )
%
% See also CertTest, GenBins, GenPDFs, GenPSDs, GenStats, uiwait, warndlg, xlswrite.


      % Delete the old file if it exists.
      % If it is open in write mode (as in Excel), prompt the user to close it.

   if ( exist( File, 'file' ) == 2 )

      fid = fopen( File, 'w' );
      while ( fid < 0 )
         beep;
         button = questdlg( sprintf( 'Unable to open  "%s" for writing. Please check file permissions or if file is in use by another program.', File ), 'File Locked!', 'retry', 'abort', 1);
         if(button == 'abort')
            break;
         end

         fid = fopen( File, 'w' );
      end % while
%       while ( fid < 0 )
%          beep;
%          HdlDgl = warndlg( sprintf( 'Please close "%s" if it is open in Excel.', File ), 'File Locked!', 'replace' );
%          uiwait( HdlDgl );
%          fid = fopen( File, 'w' );
%       end % while

      fclose( fid );
      delete( File );

   end % if

end % function DelFile( File )
