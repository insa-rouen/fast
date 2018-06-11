classdef WikiTablePrinter < TablePrinterInterface
    properties (SetAccess = protected)
        tableattributes = '';
        alignmode = 3;
    end
    methods
        function this = WikiTablePrinter(tableattributes)
            if ~ischar(tableattributes)
                error('Input argument ''tableattributes'' must be a a string.')
            end
            this.tableattributes = tableattributes;
        end
        function printEntry(this, fid, printstring, recwidth, alignmode, colspan, rowspan)
            temp = max(1,recwidth+2-length(printstring)-2*(colspan-1));
            switch alignmode
                case this.alignright
                    numlblanks = temp;
                    numrblanks = 0;
                case this.aligncenter
                    numlblanks = max(1,floor(temp/2));
                    numrblanks = ceil(temp/2);
                otherwise
                    numlblanks = 0;
                    numrblanks = temp;
            end
            fprintf(fid,'%s%s%s%s', blanks(numlblanks), printstring, blanks(numrblanks), char(repmat(1*'||',1,colspan-1)));
        end
        function printColumnStartDelimiter(this, fid)
            fprintf(fid,'||');
        end
        function printColumnCenterDelimiter(this, fid)
            fprintf(fid,'||');
        end
        function printColumnEndDelimiter(this, fid)
            fprintf(fid,'||\n');
        end
        function printTableHeader(this, fid)
            fprintf(fid,'\n|| %s\n', this.tableattributes);
        end
        function printTableEnd(this, fid)
            fprintf(fid,'');
        end
        function printEmptyTable(this, fid)
            fprintf(fid,'    empty table\n');
        end
        function out = canHandleRowspan(this)
            out = false;
        end
    end
end
