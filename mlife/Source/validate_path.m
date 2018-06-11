function path = validate_path(path)
% Make sure the path string meets the necessary requirements
% by adding a file separator at the end if needed.  
% This does not make sure the folder actually exists.
%
   
   path = strtrim(path);
   if ( isempty(path) || strcmp(path,''))
      path = [pwd filesep];
      return
   end
   
   
   
      % Add trailing file separator 
   if( ~strcmp(path(end),filesep) )
      path = [path filesep];
   end
   
      % Expand leading . into current path, but leave leading '..'
      % This is necessary because Microsoft Excel does not properly expand '.' to MatLab's working directory
   currentFolder = pwd;
   topFolder     = pwd;
   while (strcmp(path(1:2),'..'))
      path = path(4:end);
      cd ..;
      topFolder = pwd;
   end
   if (~strcmp(currentFolder,topFolder))
      cd( currentFolder );
      path = [topFolder '\' path];
   end
   if ( strcmp(path(1),'.') && ~strcmp(path(1:2), '..') )
      %currentFolder = pwd;
      path = [currentFolder  path(2:end)];
   end
   
   %Create the folder if it doesn't exist
   if ( exist(path,'dir') ~=7)
      mkdir(path);
   end
end