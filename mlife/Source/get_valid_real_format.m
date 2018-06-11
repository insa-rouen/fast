function valid = get_valid_real_format(format)

% Acceptable formats are:
%  '%10.5e'
%  '% 10.5E'
%  '%-10.4f'
%  '%+5.2F'
  
   %Check for leading %
   char = format(1);
   
   if ~(strcmp(char,'%'))
      valid = 0;
      return;
   end
   
   %Check for decimal point which is required
   decInd = strfind(format,'.');
   
   if (isempty(decInd))
      valid = 0;
      return;
   end
   
    %Search first for necessary subtype characters: e,E,f,F
   subType = format(end);
   if (isempty(subType))
      valid = 0;
      return;
   end
   
   if ~(strcmp(subType,'e') || strcmp(subType,'E') || strcmp(subType,'f') || strcmp(subType,'F') ) 
      valid = 0;
      return;
   end
   
   if ( isempty( str2num(format(2:end-1)) ) )
      valid = 0;
      return;
   end  
   % Are there other unacceptable strings?
   valid = 1;
end