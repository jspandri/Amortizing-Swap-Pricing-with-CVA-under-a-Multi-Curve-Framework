function vol_data = read_vol_matrix_data(filename)
% READ_VOL_MATRIX_DATA Read swaption volatility matrix data from Excel file.
% Extracts the matrix, strike, expiries, and tenors.
%
% INPUTS:
%   filename                   : [String/Char] string representing the name of the Excel file.
%
% OUTPUTS:
%   vol_data                   : [Struct] struct containing:
%                                  - .strike     : scalar
%                                  - .vol_matrix : matrix of normal volatilities (in decimal)
%                                  - .expiries   : vector of expiries (in years)
%                                  - .tenors     : vector of tenors (in years)

% Read file
data = readcell(filename);
first_col = string(data(:, 1));

% Find strike value
strike_idx  = find(strcmpi(strtrim(first_col), "Strike"));
if ~isempty(strike_idx)
    idx = strike_idx(1); 
    raw_strike = data{idx, 2};
    
    if isnumeric(raw_strike)
        strike = raw_strike(1) / 100; 
    elseif isstring(raw_strike) || ischar(raw_strike)
        strike = str2double(string(raw_strike)) / 100;
    end    
else
    error('Strike value not found.');
end

% Find matrix boundaries
last_row = strike_idx - 1;
while last_row > 1 && (isempty(data{last_row, 1}) || all(ismissing(data{last_row, 1})))
    last_row = last_row - 1;
end
last_col = size(data, 2);

% Extract rows and columns codes and the matrix
expiries_codes = data(2:last_row, 1);
tenors_codes = data(1, 2:last_col);
vol_matrix = str2double(string(data(2:last_row, 2:last_col))) ./ 10000;

% Transform codes into years values
expiries = extract_times(expiries_codes);
tenors = extract_times(tenors_codes);

% Save into struct
vol_data.strike = strike;
vol_data.vol_matrix = vol_matrix;
vol_data.expiries = expiries;
vol_data.tenors = tenors;

end


%% HELPER FUNCTION

% Parse time string arrays containing months (Mo) or years (Yr) into 
% fractions of a year.
function years = extract_times(labels)
codes = regexp(string(labels), '(\d+)\s*(Mo|Yr)', 'tokens', 'ignorecase');

n = numel(labels);
years = zeros(n, 1);

for i = 1:n

    if isempty(codes{i})
        years(i) = NaN;
        continue;
    end
    
    t = codes{i}{1};
    val = str2double(t{1});
    unit = upper(t{2}); 

    switch unit
        case 'MO'
            years(i) = val / 12;
        case 'YR'
            years(i) = val;
        otherwise
            years(i) = NaN;
    end
end

end