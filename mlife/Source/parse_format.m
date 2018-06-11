function [fieldWidth, precision, subtype] = parse_format(f)
   %what about minus sign in the format, this is a 'flag'??
   %Limitations:
   %  Only works with E,e,F,f subtypes with no conversion characters
   %  Only valid for those supported formats via get_valid_real_format()
   
   % Make sure this is a format we can parse!
   if ~(get_valid_real_format(f))
      % return error format ?????
      fieldWidth = 0;
      precision = 0;
      subtype = 'invalid';
      return;
   end
   l = length(f);
   numeric = sscanf(f,'%*c%f',[1 Inf]);
   fieldWidth = fix(numeric);
   precision = numeric - floor(numeric);
   if ( precision ~= 0 )
      numStr  = num2str(precision);
      s = strfind(numStr, '.');
      precision = str2double(numStr(s+1));
      
   end
   
   subtype = f(end);
end