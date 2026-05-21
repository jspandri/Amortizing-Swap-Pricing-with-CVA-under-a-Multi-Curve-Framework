function euriborSet = euribor_instruments_classifier(euribor_table, settlement)

instruments = string(euribor_table.(euribor_table.Properties.VariableNames{1}));
rates = euribor_table{:,2} ./ 100;

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


isDEPO = contains(instruments, "MO");
isSWAP = contains(instruments, "YR");
isFUT = startsWith(instruments, "ER");


if any(isDEPO)
    depo_names = instruments(isDEPO);
    depo_months = str2double(strtrim(extractBefore(depo_names, "MO")));

    datesSet.depos = following_day_convention(settlement, 0, depo_months, 0, 1, true);
    ratesSet.depos = rates(isDEPO);   
end


if any(isFUT)

    fut_names = instruments(isFUT);

    code = extractAfter(fut_names, 2);

    month_code = extractBetween(code, 1, 1);
    year_code  = extractBetween(code, 2, strlength(code));

    years = 2020 + str2double(year_code);

    months_map = containers.Map( ...
        {'F','G','H','J','K','M','N','Q','U','V','X','Z'}, ...
        1:12);

    months = arrayfun(@(c) months_map(c), month_code);

    n_futures = numel(fut_names);

    settle_dates = zeros(n_futures,1);
    expiry_dates = zeros(n_futures,1);

    for i = 1:n_futures

        settle = thirdwednesday(months(i), years(i));

        expiry_month = months(i) + 3;
        expiry_year  = years(i);

        if expiry_month > 12
            expiry_month = expiry_month - 12;
            expiry_year  = expiry_year + 1;
        end

        expiry = thirdwednesday(expiry_month, expiry_year);

        settle_dates(i) = settle;
        expiry_dates(i) = expiry;

    end

    datesSet.futures = [settle_dates expiry_dates];

    ratesSet.futures = rates(isFUT);

end


if any(isSWAP)
    swap_names = instruments(isSWAP);
    swap_years = str2double(strtrim(extractBefore(swap_names, "YR")));

    datesSet.swaps = following_day_convention(settlement, 0, 0, swap_years, 1, true);
    ratesSet.swaps = rates(isSWAP);
end

euriborSet.datesSet = datesSet;
euriborSet.ratesSet = ratesSet;

end