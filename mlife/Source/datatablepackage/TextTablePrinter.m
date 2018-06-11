classdef TextTablePrinter < TablePrinterInterface
    properties (SetAccess = protected)
        delimiter = '|';
        alignmode = 3;
    end
    methods
        function this = TextTablePrinter(delimiter)
            if nargin > 0 && ischar(delimiter)
                this.delimiter = delimiter;
            end
        end
        function printEntry(this, fid, printstring, recwidth, alignmode, colspan, rowspan)
            switch alignmode
                case this.alignleft
                    fprintf(fid,'%s%s', printstring, blanks(max(0,recwidth-length(printstring))));
                case this.aligncenter
                    temp = 0.5*(recwidth-length(printstring));
                    fprintf(fid,'%s%s%s', blanks(max(0,floor(temp))), printstring, blanks(max(0,ceil(temp))));
                otherwise
                    fprintf(fid,strcat('%',num2str(recwidth),'s'), printstring);
            end
        end
        function printColumnStartDelimiter(this, fid)
            fprintf(fid,'%s ', this.delimiter);
        end
        function printColumnCenterDelimiter(this, fid)
            fprintf(fid,' %s ', this.delimiter);
        end
        function printColumnEndDelimiter(this, fid)
            fprintf(fid,' %s\n', this.delimiter);
        end
        function printTableHeader(this, fid)
            fprintf(fid,'\n');
        end
        function printTableEnd(this, fid)
            fprintf(fid,'\n');
        end
        function printEmptyTable(this, fid)
            fprintf(fid,'    empty table\n');
        end
        function out = canHandleRowspan(this)
            out = false;
        end
    end
end