classdef HTMLTablePrinter < TablePrinterInterface
    properties (SetAccess = protected)
        tableattributes = '';
        compactform = false;
        numindent = 2;
        columnalignment = [];
        usehtmlcolgroup = false;
    end
    methods
        function this = HTMLTablePrinter(tableattributes, compactform, columnalignment)
            if nargin > 0
                if ~ischar(tableattributes)
                    error('Input argument ''tableattributes'' must be a string.')
                end
                this.tableattributes = tableattributes;
                if nargin > 1
                    if ~islogical(compactform)
                        error('Input argument ''compactform'' must be a logical.')
                    end
                    this.compactform = compactform(1);
                    if nargin > 2
                        if ~isnumeric(columnalignment)
                            error('Input argument ''columnalignment'' must be numeric.')
                        end
                        this.columnalignment = columnalignment;
                    end
                end
            end
        end
        function useColgroupStatement(this, arg)
            if arg
                this.usehtmlcolgroup = true;
            else
                this.usehtmlcolgroup = false;
            end
        end
        function printEntry(this, fid, printstring, recwidth, alignmode, colspan, rowspan)
            if colspan > 1
                if rowspan > 1
                    attr = sprintf(' colspan="%d" rowspan="%d"', colspan, rowspan);
                else
                    attr = sprintf(' colspan="%d"', colspan);
                end
            elseif rowspan > 1
                attr = sprintf(' rowspan="%d"', rowspan);
            else
                attr = '';
            end
            if ~this.usehtmlcolgroup
                if alignmode ~= this.alignnopreference
                    attr = sprintf('%s align="%s"', attr, this.aligndescriptor{alignmode});
                end
            end
            fprintf(fid,'<td%s>%s</td>', attr, printstring);
        end
        function printColumnStartDelimiter(this, fid)
            if this.compactform
                fprintf(fid,'<tr>');
            else
                fprintf(fid,'<tr>\n%s', blanks(this.numindent));
            end
        end
        function printColumnCenterDelimiter(this, fid)
            if this.compactform
                fprintf(fid,' ');
            else
                fprintf(fid,'\n%s', blanks(this.numindent));
            end
        end
        function printColumnEndDelimiter(this, fid)
            if this.compactform
                fprintf(fid,'</tr>\n');
            else
                fprintf(fid,'\n</tr>\n');
            end
        end
        function printTableHeader(this, fid)
            if isempty(this.tableattributes)
                fprintf(fid,'<table>\n');
            else
                fprintf(fid,'<table %s>\n', this.tableattributes);
            end
            if this.usehtmlcolgroup && ~isempty(this.columnalignment)
                if length(unique(this.columnalignment)) == 1
                    if this.columnalignment(1) ~= this.alignnopreference
                        fprintf(fid,'%s<colgroup align="%s"/>\n', out, this.aligndescriptor{this.columnalignment(1)});
                    end
                else
                    fprintf(fid,'%s<colgroup>\n', out);
                    y = 1;
                    while y <= length(this.columnalignment)
                        cspan = 1;
                        calign = this.columnalignment(y);
                        while y < length(this.columnalignment) && this.columnalignment(y+1) == calign;
                            cspan = cspan + 1;
                            y = y + 1;
                        end
                        if calign == this.alignnopreference
                            if cspan > 1
                                fprintf(fid,'%s%s<col span="%d"/>\n', out, blanks(this.numindent), cspan);
                            else
                                fprintf(fid,'%s%s<col/>\n', out, blanks(this.numindent));
                            end
                        else
                            if cspan > 1
                                fprintf(fid,'%s%s<col span="%d" align="%s"/>\n', out, blanks(this.numindent), cspan, this.aligndescriptor{calign});
                            else
                                fprintf(fid,'%s%s<col align="%s"/>\n', out, blanks(this.numindent), this.aligndescriptor{calign});
                            end
                        end
                        y = y + 1;
                    end
                    fprintf(fid,'%s</colgroup>\n', out);
                end
            end
        end
        function printTableEnd(this, fid)
            fprintf(fid,'</table>\n');
        end
        function printEmptyTable(this, fid)
            fprintf(fid, '\n     <!-- empty table -->\n');
        end
        function out = canHandleRowspan(this)
            out = true;
        end
    end
end
