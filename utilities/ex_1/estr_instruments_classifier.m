function estrSET = estr_instruments_classifier(estr_table, settlement)
% ESTR_INSTRUMENTS_CLASSIFIER Given an OIS ESTR instruments table read from excel, returns a set of ordered instruments with corresponding maturities and rates.
%
% INPUTS:
%   estr_table                 : [Table] excel output table with one column of instruments
%                                        maturities and one column of rates in % terms.
%   settlement                 : [Scalar] settlement date.
%
% OUTPUTS:
%   estrSET                    : [Struct] ESTR OIS Set of ordered instruments with maturities and rates:
%                                  - .settlement : settlement date
%                                  - .dates      : corresponding maturities dates
%                                  - .rates      : corresponding rates

% Extract instruments maturities and rates
instruments = string(estr_table.(estr_table.Properties.VariableNames{1}));
rates = estr_table{:,2} ./ 100;

% Initialize the struct
estrSET = struct();
estrSET.settlement = settlement;
estrSET.dates= [];
estrSET.rates = [];

% Define codes for date conversion
codes = regexp(instruments, '(\d+)\s*(DY|WK|MO|YR)', 'tokens');

n = numel(instruments);
d = zeros(n,1);
m = zeros(n,1);
y = zeros(n,1);

for i = 1:n
    % Extract codes and length
    t = codes{i}{1};
    val = str2double(t{1});
    unit = t{2};

    % Convert date interval
    switch unit
        case 'DY'
            d(i) = val;

        case 'WK'
            d(i) = val * 7;

        case 'MO'
            m(i) = val;

        case 'YR'
            y(i) = val;
    end
end

% Compute corresponding date with modified-following convention
estrSET.dates = following_day_convention(settlement, d, m, y, 1, true);
estrSET.rates = rates;

end