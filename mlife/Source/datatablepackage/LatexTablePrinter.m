classdef LatexTablePrinter < TablePrinterInterface
    properties (SetAccess = protected)
        addhline = false;
        columnspecifier = '';
    end
    methods
        function this = LatexTablePrinter(columnspecifier, addhline)
            if ischar(columnspecifier)
                this.columnspecifier = columnspecifier;
            elseif isnumeric(columnspecifier) % columnspecifier = number of columns
                this.columnspecifier = strcat(repmat('|c', 1, columnspecifier),'|');
            end
            if addhline
                this.addhline = true;
            end
        end
        function printEntry(this, fid, printstring, recwidth, alignmode, colspan, rowspan)
            if colspan == 1
                fprintf(fid,strcat('%', num2str(recwidth), 's'), printstring);
            else
                fprintf(fid,sprintf('\\\\multicolumn{%d}{|c|}{%%s}%%%ds', colspan, max(recwidth-(22+length(str)),0)), str, '');
            end
        end
        function printColumnStartDelimiter(this, fid)
            fprintf(fid, ' ');
        end
        function printColumnCenterDelimiter(this, fid)
            fprintf(fid, ' & ');
        end
        function printColumnEndDelimiter(this, fid)
            if this.addhline
                fprintf(fid,' \\\\\n \\hline\n');
            else
                fprintf(fid,' \\\\\n');
            end
        end
        function printTableHeader(this, fid)
            fprintf(fid,'\\begin{tabular}{%s}\n \\hline\n', this.columnspecifier);
        end
        function printTableEnd(this, fid)
            if this.addhline
                fprintf(fid,'\\end{tabular}\n');
            else
                fprintf(fid,' \\hline\n\\end{tabular}\n');
            end 
        end
        function printEmptyTable(this, fid)
            fprintf(fid, '\n%%     empty table\n');
        end
        function out = canHandleRowspan(this)
            out = false; % not yet
        end
    end
end