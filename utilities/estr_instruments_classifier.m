function estrSET = estr_instruments_classifier(estr_table, settlement)

instruments = string(estr_table.(estr_table.Properties.VariableNames{1}));
rates = estr_table{:,2} ./ 100;

estrSET = struct();

estrSET.settlement = settlement;
estrSET.dates= [];
estrSET.rates = [];

codes = regexp(instruments, '(\d+)\s*(DY|WK|MO|YR)', 'tokens');

n = numel(instruments);

d = zeros(n,1);
m = zeros(n,1);
y = zeros(n,1);

for i = 1:n
    t = codes{i}{1};
    val = str2double(t{1});
    unit = t{2};

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

estrSET.dates = following_day_convention(settlement, d, m, y, 1, true);
estrSET.rates = rates;

end