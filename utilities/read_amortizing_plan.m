function swapSchedule = read_amortizing_plan(filename)
% READ_AMORTIZING_PLAN Reads the swap amortizing plan from an Excel file
%   Returns a struct containing dates, year fractions, and notionals.


% Reads the table preserving the original column names (including spaces)
data = readtable(filename, 'VariableNamingRule', 'preserve');

% Payment Dates Extraction
swapSchedule.payDates = datenum(data.("Pay Date"));


% Extract accrual start and end dates (useful for future calculations)
swapSchedule.accrualStart = datenum(data.("Accrual Start"));
swapSchedule.accrualEnd = datenum(data.("Accrual End"));

% Daycount Extraction and Year Fraction Calculation (Act/360)
% Directly divide the "Days" column by 360
swapSchedule.days = data.("Days");
swapSchedule.delta = swapSchedule.days / 360; 

% Notionals Extraction
% Removes potential formatting issues and converts to a numeric array (double)
if isnumeric(data.("Notional"))
    swapSchedule.notionals = data.("Notional");
else
    % In case the Excel is read as a string due to dots/commas
    % (useful if dealing with the European format "15.000.000,00")
    notionals_str = strrep(data.("Notional"), '.', ''); % Remove thousands separators
    notionals_str = strrep(notionals_str, ',', '.');    % Change decimal comma to dot
    swapSchedule.notionals = str2double(notionals_str);
end

end