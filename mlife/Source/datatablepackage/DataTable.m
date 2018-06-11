classdef DataTable < handle
% table = DataTable() 
% create a new DataTable object. DataTable objects can used to store data
% in a table format that is easily expandable, manipulatable and that
% supports printing into a variety of formats (plain text, Latex, HTML,
% Wiki; new printing formats can be added without changing any code).
% The format of numeric table contents (e.g. number of displayed digits)
% and the alignment of text and numbers can be changed for each column
% individually.
% 
% a simple example:
% 
% >> table = DataTable();
% >> table{1,1:3} = {'column1', 'some', 'text'};
% >> table{2:3,:} = rand(2,3);
% >> table.toText()
%
% | column1 |   some |   text |
% |  0.1622 | 0.3112 | 0.1656 |
% |  0.7943 | 0.5285 | 0.6020 |
% 
% >> table.toLatex()
% \begin{tabular}{rrr}
%  \hline
%  column1 &   some &   text \\
%   0.1622 & 0.3112 & 0.1656 \\
%   0.7943 & 0.5285 & 0.6020 \\
%  \hline
% \end{tabular}
% 
% 
% - Filling a table:
%
% Use "{}" and row and column indices (both numeric and logical indexing is
% supported) to assign values to a DataTable object. E.g.
%   table{rowindices,columnindices} = values;
% where values must be a cell or a matrix with dimensions corresponding to 
% rowindex an columnindex. Alternatively, values may also be a scalar value
% or a string, in that case values is written to every specified cell. The
% "end" statement and ":" may be used as indices but be aware that a
% DataTable object is initialized as a 0x0 table, so 
%   table = DataTable();
%   table{1,:} = 3; % there are no columns yet, so ":" cannot be used! 
% will generate an error while
%   table = DataTable();
%   table{2,1:4} = 2; % there are 4 columns now
%   table{1,:} = 3; % equivalent to table{1,1:4} = 3
% will not.
%
%
% - Deleting data from a table:
%
% use the functions deleteRow and deleteColumn to delete rows or columns
% from the table.
% Type
%    help DataTable.deleteRow
%    help DataTable.deleteColumn
% for more information.
% To remove the value of a single cell or a number of cells assign '' to
% them.
% 
% example:
% >> table.toText()
%
% | 3 | 3 | 3 | 3 |
%
% >> table{1,2:3} = '';
% >> table.toText()
%
% | 3 |  |  | 3 |
% 
%
% - Printing a table
% 
% Once a table is filled, printing requires just a simple function call. 
% There are a number of printing formats available, each with a
% corresponding function.
%
%   format         function name 
%     plain text     toText
%     Latex          toLatex
%     HTML           toHTML
%     Wiki           toWiki
% 
% Each of the functions has a number of different options, more information
% is available in the functions' help, e.g. type
%    help DataTable.toLatex
% for help on the toLatex function.
% You can also write your own printer for different output formats, type
%    help DataTable.printWithPrinter
% for more information
% 
%
% - Formatting a table
% 
% The format of numbers in a table can be changed using the functions
%   setColumnFormat
%   clearColumnFormat
% Refer to their help texts for more information.
%  
% The alignment of text (and numbers) can be also changed for each column
% individually, using the functions
%   setColumnTextAlignment
%   clearColumnTextAlignment
% See their help texts for more information.
% 
% example:
% >> table.toText()
% 
% | dataset 1 | dataset 2 | dataset 3 | dataset 4 |
% |    0.0046 |    0.8173 |    0.0844 |    0.2599 |
% |    0.7749 |    0.8687 |    0.3998 |    0.8001 |
% 
% >> % use different column formats of the first three columns
% >> table.setColumnFormat(1:3, {'%1.1f', '%e', '%1.10f'});
% >> table.toText()
% 
% | dataset 1 |    dataset 2 |    dataset 3 | dataset 4 |
% |       0.0 | 8.173032e-01 | 0.0844358455 |    0.2599 |
% |       0.8 | 8.686947e-01 | 0.3997826491 |    0.8001 |
% 
% >> % change the alignment of the first three columns to center, right
% >> % and left alignment
% >> table.setColumnTextAlignment(1:3, 'crl');
% >> table.toText()
% 
% | dataset 1 |    dataset 2 | dataset 3    | dataset 4 |
% |    0.0    | 8.173032e-01 | 0.0844358455 |    0.2599 |
% |    0.8    | 8.686947e-01 | 0.3997826491 |    0.8001 |
%
%
% - Getting data from a table
%  
% The function getData can be used to return the data from a DataTable
% object. The output of getData is in cell-format. To return the data in
% double format use the function getDataDoubleFormat. See the functions'
% help texts for more information.
%  
%standardFormat
% - Combining two tables
%
% With the function appendDataTable, two DataTable objects can be combined.
% Refer to the appendDataTable help text for more information.
%
%
% DataTable version 0.81
% written by Jann Paul Mattern 
    properties (SetAccess = protected)
        numrows = 0;
        numcols = 0;
        data = cell(2,2);
        colformat = cell(1,2);
        coltextalign = ones(1,2)*TablePrinterInterface.alignnopreference;
    end
    methods
        function toText(this, varargin)
% table.toText(options)
% prints table in plain text format
%
% INPUT:
% options may include:
%   'tight':    Use a tighter format, where extra whitespace is removed.
%   'delimiter': This option is followed by a string that is used as the
%               delimiter between two columns
%
%               Default: '|' 
%
%   pid:        A valid file identifier (created with fopen) to write the 
%               table to.
%
%               Default: 1 (standard out)
            evaluated = false(1, numel(varargin));
            
            ind = strcmpi(varargin, 'tight');
            if any(ind)
                tight = true;
                evaluated(ind) = true;
            else
                tight = false;
            end
            
            ind = find(strcmpi(varargin, 'delimiter'),1);
            if ~isempty(ind)
                if numel(varargin) < ind(1) + 1
                    error('toText:InvalidInput', 'Missing argument after ''delimiter''.')
                end
                delimiter = varargin{ind+1};
                evaluated(ind:ind+1) = true;
            else
                delimiter = '|';
            end
            
            ind = find(cellfun(@isnumeric, varargin),1);
            if ~isempty(ind)
                try
                    ftell(varargin{ind});
                catch err
                    error('toLatex:InvalidInput', 'Argument #%d is an invalid file identifier.', ind + 1)
                end
                fid = varargin{ind};
                evaluated(ind) = true;
            else
                fid = 1;
            end
            
            if ~all(evaluated)
                ind = find(~evaluated, 1);
                error('toText:InvalidInput', 'Unknown argument #%d.', ind)
            end
            
            this.printTableBody(fid, tight, TextTablePrinter(delimiter))
        end
        function toLatex(this, varargin)
% table.toLatex(options)
% prints table in Latex format
%
% INPUT:
% options may include:
%   'tight':    Use a tighter format, where extra whitespace is removed.
%   'hline':    Include horizontal lines "\hline" in between every two
%               lines.
%   'formatter': This option is followed by a string that is included in
%               the Latex tabular column format string.
%
%               Example:
%                    table.toLatex('formatter', 'ccrr'
%                  will result in the output:
%                    \begin{tabular}{ccrr}
%                      ...
%
%               Default: 
%                 The default Latex column format string is derived from
%                 the number of columns and their text alignment settings.
%
%   pid:        A valid file identifier (created with fopen) to write the 
%               table to. 
%
%               Default: 1 (standard out)
            evaluated = false(1, numel(varargin));
            
            ind = strcmpi(varargin, 'hline');
            if any(ind)
                addhline = true;
                evaluated(ind) = true;
            else
                addhline = false;
            end
            
            ind = strcmpi(varargin, 'tight');
            if any(ind)
                tight = true;
                evaluated(ind) = true;
            else
                tight = false;
            end
            
            ind = find(strcmpi(varargin, 'formatter'),1);
            if ~isempty(ind)
                if numel(varargin) < ind(1) + 1
                    error('toLatex:InvalidInput', 'Missing argument after ''formatter''.')
                end
                formatter = varargin{ind+1};
                evaluated(ind:ind+1) = true;
            else
                ind = this.coltextalign(1,1:this.numcols);
                ind(ind == TablePrinterInterface.alignnopreference) = TablePrinterInterface.alignright;
                formatter = TablePrinterInterface.aligndescriptorshort(ind);
            end
            
            ind = find(cellfun(@isnumeric, varargin),1);
            if ~isempty(ind)
                try
                    ftell(varargin{ind});
                catch err
                    error('toLatex:InvalidInput', 'Argument #%d is an invalid file identifier.', ind + 1)
                end
                fid = varargin{ind};
                evaluated(ind) = true;
            else
                fid = 1;
            end
            
            if ~all(evaluated)
                ind = find(~evaluated, 1);
                error('toLatex:InvalidInput', 'Unknown argument #%d.', ind)
            end
            
            this.printTableBody(fid, tight, LatexTablePrinter(formatter, addhline))
        end
        function toWiki(this, varargin)
% table.toWiki(options)
% prints table in Wiki format
%
% INPUT:
% options may include:
%   'tight':    Use a tighter format, where extra whitespace is removed.
%   'tableattributes': This option is followed by a string that is included
%               in the Wiki table header.
%
%               Example:
%                    table.toWiki('tableattributes', 'border=1'
%                  will result in the output:
%                    || border=1
%                    ...
%                   
%   pid:        A valid file identifier (created with fopen) to write the 
%               table to. 
%
%               Default: 1 (standard out)
            evaluated = false(1, numel(varargin));
            
            ind = strcmpi(varargin, 'tight');
            if any(ind)
                tight = true;
                evaluated(ind) = true;
            else
                tight = false;
            end
            
            ind = find(strcmpi(varargin, 'tableattributes'),1);
            if ~isempty(ind)
                if numel(varargin) < ind(1) + 1
                    error('toWiki:InvalidInput', 'Missing argument after ''tableattributes''.')
                end
                tableattributes = varargin{ind+1};
                evaluated(ind:ind+1) = true;
            else
                tableattributes = 'border=1';
            end
            
            ind = find(cellfun(@isnumeric, varargin),1);
            if ~isempty(ind)
                try
                    ftell(varargin{ind});
                catch err
                    error('toWiki:InvalidInput', 'Argument #%d is an invalid file identifier.', ind + 1)
                end
                fid = varargin{ind};
                evaluated(ind) = true;
            else
                fid = 1;
            end
            
            if ~all(evaluated)
                ind = find(~evaluated, 1);
                error('toWiki:InvalidInput', 'Unknown argument #%d.', ind)
            end
            
            this.printTableBody(fid, tight, WikiTablePrinter(tableattributes))
        end
        function toHTML(this, varargin)
% table.toHTML(options)
% prints table in HTML format
%
% INPUT:
% options may include:
%   'tight':    Use a tighter format, where each row is contained in one 
%               line of text.
%   'usecolgroup': Use the HTML "colgroup" statement instead of
%               including the alignment information int each cell
%               individually.
%   'tableattributes': This option is followed by a string that is included
%               in the HTML opening table tag.
%
%               Example:
%                    table.toHTML('tableattributes', 'border="1"'
%                  will result in the output:
%                    <table border="1">
%                      ...
%                    </table>
%
%   pid:        A valid file identifier (created with fopen) to write the 
%               table to. 
%
%               Default: 1 (standard out)
            evaluated = false(1, numel(varargin));
            
            ind = strcmpi(varargin, 'tight');
            if any(ind)
                tight = true;
                evaluated(ind) = true;
            else
                tight = false;
            end
            
            ind = strcmpi(varargin, 'usecolgroup');
            if any(ind)
                usecolgroup = true;
                evaluated(ind) = true;
            else
                usecolgroup = false;
            end
            
            ind = find(strcmpi(varargin, 'tableattributes'),1);
            if ~isempty(ind)
                if numel(varargin) < ind(1) + 1
                    error('toHTML:InvalidInput', 'Missing argument after ''tableattributes''.')
                end
                tableattributes = varargin{ind+1};
                evaluated(ind:ind+1) = true;
            else
                tableattributes = '';
            end
            
            ind = find(cellfun(@isnumeric, varargin),1);
            if ~isempty(ind)
                try
                    ftell(varargin{ind});
                catch err
                    error('toHTML:InvalidInput', 'Argument #%d is an invalid file identifier.', ind + 1)
                end
                fid = varargin{ind};
                evaluated(ind) = true;
            else
                fid = 1;
            end
            
            if ~all(evaluated)
                ind = find(~evaluated, 1);
                error('toHTML:InvalidInput', 'Unknown argument #%d.', ind)
            end
            
            columnalignment = this.coltextalign(1,1:this.numcols);
            
            printer = HTMLTablePrinter(tableattributes, tight, columnalignment);
            printer.useColgroupStatement(usecolgroup);
            this.printTableBody(fid, tight, printer);
        end
        function printWithPrinter(this, printer, fid)
% table.printWithPrinter(printer)
%   or 
% table.printWithPrinter(printer, pid)
% print table with a custom printer 
%
% INPUT:
%   printer:    An object implementing the TablePrinterInterface abstract
%               class.
%   pid:        A valid file identifier (created with fopen) to write the 
%               table to.
%
%               Default: 1 (standard out)
            if ~isa(printer, 'TablePrinterInterface')
                error('First input argument ''printer'' must be an object of a class implementing the TablePrinterInterface.')
            end
            if nargin < 3
                fid = 1;
            end
            if this.numrows == 0 || this.numcols == 0
                fprintf(fid, '\n     empty table\n');
                return
            end
            
            this.printTableBody(fid, false, printer)
        end
        function deleteRow(this, index)
% table.deleteRow(index)
% delete row(s) from table
%
% INPUT:
%   index:      Numeric or logical index specifying the rows to delete.
            if size(index,1) > 1
                index = index(:)';
            end
            if islogical(index)
                if length(index) > this.numrows
                    error('deleteRow:InvalidInput', 'Row indices out of bounds.')
                end
                numdelete = sum(index);
            elseif isnumeric(index)
                if any(index < 1) || any(index > this.numrows)
                    error('deleteRow:InvalidInput', 'Row indices out of bounds.')
                end
                numdelete = length(unique(index));
            else
                error('deleteRow:InvalidInput', 'Invalid row indices.')
            end
            try
                this.data(index,:) = [];
            catch err
                error('deleteRow:InvalidInput', 'Invalid row indices.')
            end
            this.numrows = this.numrows - numdelete;
        end
        function deleteColumn(this, index)
% table.deleteColumn(index)
% delete column(s) from table
%
% INPUT:
%   index:      Numeric or logical index specifying the columns to delete.
            if size(index,1) > 1
                index = index(:)';
            end
            if islogical(index)
                if length(index) > this.numcols
                    error('deleteColumn:InvalidInput', 'Column indices out of bounds.')
                end
                numdelete = sum(index);
            elseif isnumeric(index)
                if any(index < 1) || any(index > this.numcols)
                    error('deleteColumn:InvalidInput', 'Column indices out of bounds.')
                end
                numdelete = length(unique(index));
            else
                error('deleteColumn:InvalidInput', 'Invalid column indices.')
            end
            try
                this.data(:,index) = [];
                this.colformat(index) = [];
                this.coltextalign(index) = [];
            catch err
                error('deleteColumn:InvalidInput', 'Invalid column indices.')
            end
            this.numcols = this.numcols - numdelete;
        end
        function appendDataTable(this, location, table)
% table.appendDataTable(location, table2)
% append another DataTable object to table
%
% INPUT:
%   location:   Either 'right', 'left', 'top' or 'bottom' specifying where
%               to append the other table.
%   table2:     The table to append (must be a DataTable object).
            if nargin < 3
                table = location;
                locationind = 1; % right
            else
                if ~ischar(location)
                    error('appendDataTable:InvalidInput', 'Location specifier must be a string.')
                end
                locationind = find(strncmpi(location, {'right', 'left', 'top', 'bottom'}, length(location)));
                if isempty(locationind)
                    error('appendDataTable:InvalidInput', 'Invalid location specifier, use ''right'', ''left'', ''top'' or ''bottom''.')
                end
            end
            if ~isa(table, 'DataTable')
                error('appendDataTable:InvalidInput', 'Second input argument ''datatable'' must be a DataTable object.');
            end
            otherdata = table.getData();
            othercolformat = table.getColumnFormat();
            otheralformat = table.getColumnTextAlignment();
            oldnumrows = this.numrows;
            oldnumcols = this.numcols;
            
            switch locationind
                case 1
                    rowindex = 1:size(otherdata,1);
                    colindex = oldnumcols+1:oldnumcols+size(otherdata,2);
                    
                    this.expandData(rowindex(end), colindex(end), true);
                    this.data(rowindex,colindex) = otherdata;
                    this.setColumnFormat(colindex, othercolformat);
                    this.setColumnTextAlignment(colindex, otheralformat);
                case 2
                    rowindex = 1:oldnumrows;
                    colindex = size(otherdata,2)+1:size(otherdata,2)+oldnumcols;
                    
                    this.expandData(size(otherdata,1), colindex(end), true);
                    this.data(rowindex,colindex) = this.data(1:oldnumrows,1:oldnumcols);
                    this.colformat(1,colindex) = this.colformat(1,1:oldnumcols);
                    this.coltextalign(1,colindex) = this.coltextalign(1,1:oldnumcols);
                    if oldnumrows > size(otherdata,1)
                        this.data(size(otherdata,1)+1:oldnumrows,1:size(otherdata,2)) = cell(oldnumrows-size(otherdata,1), size(otherdata,2));
                    end
                    this.data(1:size(otherdata,1),1:size(otherdata,2)) = otherdata;
                    this.colformat(1,1:size(otherdata,2)) = othercolformat;
                    this.coltextalign(1,1:size(otherdata,2)) = otheralformat;
                case 3
                    rowindex = size(otherdata,1)+1:size(otherdata,1)+oldnumrows;
                    colindex = 1:oldnumcols;
                    
                    this.expandData(rowindex(end), size(otherdata,2), true);
                    this.data(rowindex,colindex) = this.data(1:oldnumrows,1:oldnumcols);
                    if oldnumcols > size(otherdata,2)
                        this.data(1:size(otherdata,1),size(otherdata,2)+1:oldnumcols) = cell(size(otherdata,1), oldnumcols-size(otherdata,2));
                    end
                    this.data(1:size(otherdata,1),1:size(otherdata,2)) = otherdata;
                case 4
                    rowindex = oldnumrows+1:oldnumrows+size(otherdata,1);
                    colindex = 1:size(otherdata,2);
                    
                    this.expandData(rowindex(end), colindex(end), true);
                    this.data(rowindex,colindex) = otherdata;
            end
        end
        function out = getData(this, rowindex, colindex)
% data = table.getData()
%   or 
% data = table.getData(rowindex, columnindex)
% returns the table's data in cell format
%
% INPUT:
%   rowindex:   Numeric or logical row index.
%   columnindex: Numeric or logical column index.
%
% OUTPUT:
%   data:       A cell containing the table's data.   
            switch nargin
                case 1 
                    out = this.data(1:this.numrows, 1:this.numcols);
                case 3
                    if islogical(rowindex) && numel(rowindex) > this.numrows
                        error('DataTable:getData', 'Invalid index.\nRow index exceeds table dimensions.')
                    elseif isnumeric(rowindex) && any(rowindex > this.numrows)
                        error('DataTable:getData', 'Invalid index.\nRow index exceeds table dimensions.')
                    end
                    if islogical(colindex) && numel(colindex) > this.numcols
                        error('DataTable:getData', 'Invalid index.\nColumn index exceeds table dimensions.')
                    elseif isnumeric(colindex) && any(colindex > this.numcols)
                        error('DataTable:getData', 'Invalid index.\nColumn index exceeds table dimensions.')
                    end
                    out = this.data(rowindex, colindex);
                otherwise
                    error('DataTable:getData', 'Invalid number of input arguments.\nType ''help DataTable.getData'' for more information.')
            end
        end
        function out = getDataDoubleFormat(this, rowindex, colindex)
% data = table.getDataDoubleFormat()
%   or 
% data = table.getDataDoubleFormat(rowindex, columnindex)
% returns the table's data in double format, strings and empty cells are
% replaced by NaNs. 
%
% INPUT:
%   rowindex:   Numeric or logical row index.
%   columnindex: Numeric or logical column index.
%
% OUTPUT:
%   data:       A double matrix containing the table's data. Strings and
%               empty cells are replaced by NaNs, logicals integers, etc
%               are converted to doubles.
            switch nargin
                case 1
                    celldata = this.data(1:this.numrows, 1:this.numcols);
                case 3
                    try 
                        celldata = this.getData(rowindex, colindex);
                    catch err
                        error('DataTable:getDataDoubleFormat', err.message)
                    end
                otherwise
                    error('DataTable:getDataDoubleFormat','Invalid number of input arguments.\nType ''help DataTable.getDataDoubleFormat'' for more information.')
            end
            convertableind = ~(cellfun(@ischar, celldata) | cellfun(@isempty, celldata));
            out = nan(size(celldata));
            out(convertableind) = [celldata{convertableind}];
        end
        function out = getColumnFormat(this)
            out = this.colformat(1, 1:this.numcols);
        end
        function setColumnFormat(this, index, format)
% table.setColumnFormat(index, format)
%   or
% table.setColumnFormat(format)
% set a format for all numeric arguments in the specified columns
%
% INPUT:
%   index:      Numeric or logical index specifying the columns the format
%               is applied to.
%               If ommitted the format is applied to all columns.
%   format:     A string containing a format specifier, that is used by the
%               function fprintf, e.g. %5.3f or %e (type 'help fprinf' for
%               more information).
%               
%               Example:
%                 table.setColumnFormat(1:3, '%5.2f')

            if nargin == 2
                format = index;
                index = 1:this.numcols;
            end
            if isnumeric(index)
                if any(index < 0) || any(index > this.numcols)
                    error('setColumnFormat:InvalidInput', 'Invalid column index.')
                end
                numindices = numel(index);
            elseif islogical(index)
                numindices = sum(index(:));
                index = index(1:min(numel(index), this.numcols));
            else
                error('setColumnFormat:InvalidInput', 'Invalid column index.')
            end
            if ischar(format)
                this.colformat(index) = {format};
            elseif iscellstr(format)
                if numel(format) == 1
                    this.colformat(index) = format;
                else
                    if numel(format) ~= numindices
                        error('setColumnFormat:InvalidInput', 'Number of indices does not match number of format strings.')
                    end
                    this.colformat(index) = format;
                end
            elseif iscell(format) && all(cellfun(@isempty, format))
                return
            else
                error('setColumnFormat:InvalidInput', 'Input argument ''colformat'' must be a string or a cell-string.')
            end
        end
        function clearColumnFormat(this, index)
% table.clearColumnFormat(index)
%   or
% table.clearColumnFormat()
% clear the format set by setColumnFormat
%
% INPUT:
%   index:      Numeric or logical index specifying the columns the format
%               is cleared from.
%               If ommitted the format is cleared from all columns.
            if nargin == 1
                this.setColumnFormat(1:this.numcols, '');
            else
                try
                    this.setColumnFormat(index, '');
                catch err
                    error('clearColumnFormat:InvalidInput', 'Invalid column index.')
                end
            end
        end
        function out = getColumnTextAlignment(this)
            out = this.coltextalign(1, 1:this.numcols);
        end
        function setColumnTextAlignment(this, index, alignment)
% table.setColumnTextAlignment(index, alignment)
%   or
% table.setColumnTextAlignment(alignment)
% set a alignment for all numeric arguments in the specified columns
%
% INPUT:
%   index:      Numeric or logical index specifying the columns the
%               alignment is applied to.
%               If ommitted the alignment is applied to all columns.
%   alignment:  Either 'right', 'left' or 'center' or a cell-string with 
%               the same number of elements as index
%               Alternatively alignment may a string consisting of the 
%               characters 'r', 'l', 'c' (for right, left, center
%               respectively) with a character for every entry in index.
%               
%               Example:
%                 table.setColumnFormat(1:3, {'left', 'center', 'right'})
%                   and 
%                 table.setColumnFormat(1:3, 'lcr')
%                   have the same effect and left-align the text in the
%                   first column, center-align in the second column and
%                   right-align the text in the third column.

            if nargin == 2
                alignment = index;
                index = 1:this.numcols;
            end
            if isnumeric(index)
                if any(index < 0) || any(index > this.numcols)
                    error('setColumnTextAlignment:InvalidInput', 'Invalid column index.')
                end
                numindices = numel(index);
            elseif islogical(index)
                numindices = sum(index(:));
                index = index(1:min(numel(index), this.numcols));
            else
                error('setColumnTextAlignment:InvalidInput', 'Invalid column index.')
            end
            
            % convert to numbers; alignment -> format
            if isnumeric(alignment)
                format = alignment;
            elseif ischar(alignment)
                format = find(strncmpi(TablePrinterInterface.aligndescriptor, alignment, length(alignment)));
                if isempty(format)
                    % see if it something like 'crrrl'
                    try
                        format = arrayfun(@(x) find(strncmpi(TablePrinterInterface.aligndescriptor, x, 1)), alignment);
                    catch err
                        error('setColumnTextAlignment:InvalidInput', 'Invalid alignment specifier, use ''r'' (or ''right''), ''l'' (or ''left''), ''c'' (or ''center'').')
                    end
                end
            elseif iscellstr(alignment)
                try
                    format = cellfun(@(x) find(strncmpi(TablePrinterInterface.aligndescriptor, x, length(x))), alignment);
                catch err
                    error('setColumnTextAlignment:InvalidInput', 'Invalid alignment specifier, use ''r'' (or ''right''), ''l'' (or ''left''), ''c'' (or ''center'').')
                end
            else
                error('setColumnTextAlignment:InvalidInput', 'Input argument ''alignment'' must be numeric, a string or a cell-string.')
            end
            if numel(format) == 1
                this.coltextalign(index) = format;
            else
                if numel(format) ~= numindices
                    error('setColumnTextAlignment:InvalidInput', 'Number of indices does not match number of alignment specifiers.')
                end
                this.coltextalign(index) = format;
            end
        end
        function clearColumnTextAlignment(this, index)
% table.clearColumnTextAlignment(index)
%   or
% table.clearColumnTextAlignment()
% clear the alignment set by setColumnTextAlignment
%
% INPUT:
%   index:      Numeric or logical index specifying the columns the 
%               alignment is cleared from.
%               If ommitted the alignment is cleared from all columns.
            if nargin == 1
                this.setColumnTextAlignment(1:this.numcols, TablePrinterInterface.alignnopreference);
            else
                try
                    this.setColumnTextAlignment(index, TablePrinterInterface.alignnopreference);
                catch err
                    error('setColumnFormat:InvalidInput', 'Invalid column index.')
                end
            end
        end
        function varargout = size(this, dim)
            if nargin == 1
                if nargout == 2
                    varargout{1} = this.numrows;
                    varargout{2} = this.numcols;
                else
                    varargout{1} = [this.numrows this.numcols];
                end
            else
                switch dim
                    case 1
                        varargout{1} = this.numrows;
                    case 2
                        varargout{1} = this.numcols;
                    otherwise
                        error('size:InvalidInput', 'Invalid dimension.');
                end
            end
        end
        % for convenient indexing
        function this = subsasgn(this, index, paramvalue)
            if ~strcmpi(index.type, '{}')
                error('DataTable:subsasgn', 'Invalid assignment to a DataTable object!\nUse {} to assign values to a DataTable object.')
            end
            if numel(index.subs) ~= 2
                if numel(index.subs) == 1 && strcmpi(index.subs{1}, 'new')
                    rowindex = this.numrows + 1;
                    colindex = 1:this.numcols;
                else
                    error('DataTable:subsasgn', 'Invalid assignment to a DataTable object!\nUse 2 indices (row and column) to assign values to a DataTable object.')
                end
            else
                if strcmp(index.subs{1},':');
                    rowindex = 1:this.numrows;
                else
                    rowindex = index.subs{1};
                end
                if strcmp(index.subs{2},':');
                    colindex = 1:this.numcols;
                else
                    colindex = index.subs{2};
                end
            end
            if isempty(rowindex) || isempty(colindex)
                error('DataTable:subsasgn', 'Invalid assignment to a DataTable object!')
            end
            
            % single string or numeric etc, but not cell
            singleinput = false;
            
            % check cells
            if iscell(paramvalue)
                if any(cellfun(@(x) numel(x)>1 && ~ischar(x), paramvalue))
                    error('DataTable:subsasgn', 'Invalid assignment to a DataTable object!\nA table cell may not contain a vector.')
                end
            elseif ischar(paramvalue) || numel(paramvalue) == 1  % single input may not be cell
                singleinput = true;
            end
            
            if ~singleinput
                % compare dimensions
                numinputrows = size(paramvalue,1);
                numinputcols = size(paramvalue,2);
                if numinputrows ~= length(rowindex)
                    error('DataTable:subsasgn', 'Invalid assignment to a DataTable object!\nAssignment dimension mismatch; number of rows does not match number of row indices.')
                elseif numinputcols ~= length(colindex)
                    error('DataTable:subsasgn', 'Invalid assignment to a DataTable object!\nAssignment dimension mismatch; number of columns does not match number of column indices.')
                elseif numinputrows*numinputcols ~= numel(paramvalue)
                    error('DataTable:subsasgn', 'Invalid assignment to a DataTable object!\nAssignment dimension mismatch.')
                end
            end
            
            % expand 'data' if necessary, 'vector behaviour' for less copying
            this.expandData(max(rowindex),max(colindex), true);
            
            if iscell(paramvalue)
                this.data(rowindex, colindex) = paramvalue;
            elseif singleinput
                if length(rowindex)*length(colindex) > 1
                    for x = 1:length(rowindex)
                        for y = 1:length(colindex)
                            this.data{rowindex(x),colindex(y)} = paramvalue;
                        end
                    end
                else
                    this.data{rowindex, colindex} = paramvalue;
                end
            else
                for x = 1:numel(rowindex)
                    for y = 1:numel(colindex)
                        this.data{rowindex(x),colindex(y)} = paramvalue(x,y);
                    end
                end
            end
        end
        function out = end(this, pos, num)
            if num == 2
                if pos == 1
                    out = this.numrows;
                else
                    out = this.numcols;
                end
            else
                out = this.numcols*this.numrows;
            end
        end
        function display(this)
            fprintf('\n    %dx%d DataTable\n', this.numrows, this.numcols)
            this.toText();
        end
        function disp(this)
            this.display;
        end
    end
    methods (Hidden = true)
        function printTableBody(this, fid, tight, printer)
            if this.numrows == 0 || this.numcols == 0
                printer.printEmptyTable(fid);
                return
            end
            strdata = this.standardFormat(this.applyColumnFormat());
            colwidth = max(cellfun(@length, strdata), [], 1);
            
            usecolspan = false; % no colspan at this moment
            
            printer.printTableHeader(fid);
            for x = 1:this.numrows
                lastentry = '';
                lastentrycol = 1;
                y = 1;
                printer.printColumnStartDelimiter(fid);
                while true
                    if usecolspan
                        while y <= this.numcols && isempty(strdata{x,y})
                            y = y + 1;
                        end
                    end
                    if y > 1
                        colspan = y-lastentrycol;
                        if tight
                            reccolwidth = 0;
                        else
                            reccolwidth = sum(colwidth(lastentrycol:y-1));
                        end
                        
                        printer.printEntry(fid, lastentry, reccolwidth, this.coltextalign(y-1), colspan, 1);
                        if y <= this.numcols
                            printer.printColumnCenterDelimiter(fid);
                        end
                    end
                    
                    if y > this.numcols
                        printer.printColumnEndDelimiter(fid);
                        break;
                    end
                    lastentry = strdata{x,y};
                    lastentrycol = y;
                    y = y + 1;
                end
            end
            printer.printTableEnd(fid);
        end
        function out = applyColumnFormat(this)
            out = this.data(1:this.numrows, 1:this.numcols);
            for y = 1:this.numcols
                if isempty(this.colformat{y})
                    out(:,y) = this.standardFormat(out(:,y));
                else
                    indnonstandard = cellfun(@isnumeric, out(:,y));
                    out(indnonstandard,y) = cellfun(@(x) sprintf(this.colformat{y},x), out(indnonstandard,y), 'UniformOutput', false);
                    out(~indnonstandard,y) = this.standardFormat(out(~indnonstandard,y));
                end
            end
        end
        function str = standardFormat(this, arg) % leave non-static as it may later become depedent on class variables
            if isfloat(arg)
                if rem(arg, 1) == 0
                    str = sprintf('%d', arg);
                elseif abs(arg) > 999999999
                    str = sprintf('%10.4e', arg);
                elseif abs(arg) < 0.001
                    str = sprintf('%10.4e', arg);
                else
                    str = sprintf('%1.4f', arg);
                end
            elseif isnumeric(arg)
                str = num2str(arg);
            elseif ischar(arg)
                str = arg;
            elseif islogical(arg)
                if arg
                    str = 'true';
                else
                    str = 'false';
                end
            elseif iscell(arg)
                str = cellfun(@this.standardFormat, arg, 'UniformOutput', false);
            end
        end
        function expandData(this, maxrowind, maxcolind, updatesize)
            if maxrowind > size(this.data,1) || maxcolind > size(this.data,2)
                rind = 2^ceil(log2(double(max(maxrowind, size(this.data,1)))));
                cind = 2^ceil(log2(double(max(maxcolind, size(this.data,2)))));
                this.data{rind, cind} = [];
                this.colformat{1,cind} = '';
                this.coltextalign(1,this.numcols+1:cind) = TablePrinterInterface.alignnopreference;
            end
            if nargin >=4 && updatesize
                this.numrows = max(this.numrows, maxrowind);
                this.numcols = max(this.numcols, maxcolind);
            end
        end
        
    end
end