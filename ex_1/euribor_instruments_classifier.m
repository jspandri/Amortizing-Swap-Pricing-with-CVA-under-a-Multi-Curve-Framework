function euriborSet = euribor_instruments_classifier(euribor_table, settlement)
% Given an EURIBOR3m instruments table read from excel, returns a set of
% classified (depos, futures, swaps) and ordered instruments with 
% corresponding maturities and rates.
%
% INPUTS:
%   euribor_table       - excel output table with one column of 
%                         instruments names and one column of rates in % 
%                         terms.
%   settlement          - settlement date.
%
% OUTPUTS:
%   euriborSet          - Euribor3m Set of classified and ordered 
%                         instruments with maturities and rates.

% Extract instruments maturities and rates
instruments = string(euribor_table.(euribor_table.Properties.VariableNames{1}));
rates = euribor_table{:,2} ./ 100;

% Initialize the structs
euriborSet = struct();
datesSet = struct();
ratesSet = struct();
datesSet.settlement = settlement;
datesSet.depos = [];
datesSet.futures = [];
datesSet.swaps = [];
ratesSet.depos = [];
ratesSet.futures = [];
ratesSet.swaps = [];

% Find each kind of instrument
isDEPO = contains(instruments, "MO");  % Depo
isSWAP = contains(instruments, "YR");  % Swap
isFUT = startsWith(instruments, "ER"); % Future

% DEPOS
if any(isDEPO)
    depo_names = instruments(isDEPO);
    % Extract maturity
    depo_months = str2double(strtrim(extractBefore(depo_names, "MO")));

    % Compute maturity date
    datesSet.depos = following_day_convention(settlement, 0, depo_months, 0, 1, true);
    ratesSet.depos = rates(isDEPO);   
end

% FUTURES
if any(isFUT)
    fut_names = instruments(isFUT);
    
    % Extract and convert start month code
    code = extractAfter(fut_names, 2);
    month_code = extractBetween(code, 1, 1);
    year_code  = extractBetween(code, 2, strlength(code));
    years = 2020 + str2double(year_code);

    % Convert month code to actual month 
    months_map = containers.Map( ...
        {'F','G','H','J','K','M','N','Q','U','V','X','Z'}, ...
        1:12);
    months = arrayfun(@(c) months_map(c), month_code);

    n_futures = numel(fut_names);

    start_dates = zeros(n_futures,1);
    expiry_dates = zeros(n_futures,1);

    for i = 1:n_futures
        % Compute start date
        start_date = thirdwednesday(months(i), years(i));
        
        % Compute expiries
        expiry_month = months(i) + 3;
        expiry_year  = years(i);
        if expiry_month > 12
            expiry_month = expiry_month - 12;
            expiry_year  = expiry_year + 1;
        end
        expiry = thirdwednesday(expiry_month, expiry_year);

        start_dates(i) = start_date;
        expiry_dates(i) = expiry;
    end
    % Save both start and expiry dates
    datesSet.futures = [start_dates expiry_dates];
    ratesSet.futures = rates(isFUT);
end


% SWAPS
if any(isSWAP)
    swap_names = instruments(isSWAP);
    % Extract length
    swap_years = str2double(strtrim(extractBefore(swap_names, "YR")));
    % Compute maturity
    datesSet.swaps = following_day_convention(settlement, 0, 0, swap_years, 1, true);
    ratesSet.swaps = rates(isSWAP);
end

euriborSet.datesSet = datesSet;
euriborSet.ratesSet = ratesSet;
end