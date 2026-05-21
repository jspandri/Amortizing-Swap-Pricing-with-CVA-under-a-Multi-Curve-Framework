function [discounts, pseudo_discounts] = multi_curve_bootstrap(euriborSet, estrSet)

settlement = estrSet.settlement;

%% DISCOUNTING CURVE (OIS ESTR Curve)

estrDates = estrSet.dates;
estrRates = estrSet.rates;

target_1y = following_day_convention(settlement, 0, 0, 1, 1, true);

idx_below_1y = (estrDates <= target_1y);
idx_above_1y = find(~idx_below_1y);

discounts = zeros(length(estrDates), 1);

deltas = yearfrac(settlement, estrDates, 2);

discounts(idx_below_1y) = 1 ./ (1 + deltas(idx_below_1y) .* estrRates(idx_below_1y));


for i = 1:length(idx_above_1y)

    idx = idx_above_1y(i);
    T = estrDates(idx);
    R_ois = estrRates(idx);

    schedule = generate_schedule_with_stub(settlement, T);

    % CASE > 1 YEAR
    % (if there are more than 2 dates => there are intermediate swaps)
    if length(schedule) > 2 

        t_prev = schedule(1:end-2);
        t_curr = schedule(2:end-1);

        deltas_k = yearfrac(t_prev, t_curr, 2); % ACT/360

        t_known = estrDates(1:idx-1);
        discounts_known = discounts(1:idx-1);

        discounts_k = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
                      t_curr, t_known, discounts_known);

        fixed_leg = sum(deltas_k(:) .* discounts_k(:));

    % CASE <= 1 YEAR
    % (no intermediate swaps => only settle and maturity dates)
    else 

        % no fixed leg payments
        fixed_leg = 0; 
    end    

    delta_i = yearfrac(schedule(end-1), schedule(end), 2); % ACT/360

    discounts(idx) = (1 - R_ois * fixed_leg) / (1 + delta_i * R_ois);

end  

%% PSEUDO-DISCOUNTING CURVE (Euribor3m curve)

% 1) 3m DEPO (3m discount)

depo_dates = euriborSet.datesSet.depos;
depo_rates = euriborSet.ratesSet.depos;

days = depo_dates - settlement;
idx_3m = find(days >= 85 & days <= 95, 1);

if isempty(idx_3m)
    error("No 3 months depo found.");
end

depo_date = depo_dates(idx_3m);
depo_rate = depo_rates(idx_3m);

delta = yearfrac(settlement, depo_date, 2); % ACT/360

depo_discount = 1 / (1 + delta * depo_rate);

pseudo_dates = [settlement; depo_date];
pseudo_discounts = [1; depo_discount];



% 2) 3x6 Future (6m discount)

futures_starts = euriborSet.datesSet.futures(:, 1);
futures_ends = euriborSet.datesSet.futures(:, 2);
futures_rates = euriborSet.ratesSet.futures;

idx_3x6 = find_future_idx(settlement, futures_starts, 3);
start_3x6 = futures_starts(idx_3x6);
end_3x6 = futures_ends(idx_3x6);
rate_3x6 = futures_rates(idx_3x6);

discount_start = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
               start_3x6, pseudo_dates, pseudo_discounts);

delta = yearfrac(start_3x6, end_3x6, 2); % ACT/360


discount_end = discount_start / (1 + delta * rate_3x6);

pseudo_dates = [pseudo_dates; end_3x6];
pseudo_discounts = [pseudo_discounts; discount_end];


% 3) Backward step: 1x4 and 2x5 futures (1m and 2m discounts)

for i = 1:2
    
    idx_future = find_future_idx(settlement, futures_starts, i);
    start_future = futures_starts(idx_future);
    end_future = futures_ends(idx_future);
    rate_future = futures_rates(idx_future);

    discount_end = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
                   end_future, pseudo_dates, pseudo_discounts);

    delta = yearfrac(start_future, end_future, 2); % ACT/360

    discount_start = discount_end * (1 + delta * rate_future);

    pseudo_dates = [pseudo_dates; start_future];
    pseudo_discounts = [pseudo_discounts; discount_start];
end    

end