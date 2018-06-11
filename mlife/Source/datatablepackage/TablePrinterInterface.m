classdef TablePrinterInterface < handle
    properties (Constant = true)
        alignleft = 1;
        aligncenter = 2;
        alignright = 3;
        alignnopreference = 4;
        aligndescriptor = {'left', 'center', 'right', 'no preference'};
        aligndescriptorshort = 'lcrn';
    end
    methods (Abstract)
        printEntry(fid, printstring, recwidth, alignmode, colspan, rowspan)
        printColumnStartDelimiter(fid)
        printColumnCenterDelimiter(fid)
        printColumnEndDelimiter(fid)
        printTableHeader(fid)
        printTableEnd(fid)
        printEmptyTable(fid)
        out = canHandleRowspan()
    end
end