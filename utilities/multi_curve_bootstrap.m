function [discountCurve, pseudoCurve] = multi_curve_bootstrap(euriborSet, estrSet)

settlement = estrSet.settlement;

%% DISCOUNTING CURVE (OIS ESTR Curve)

estrDates = estrSet.dates;
estrRates = estrSet.rates;

% Spline interpolate yearly rates (since from 12y on they are not yearly
% anymore)
longest_mat_years = round(yearfrac(settlement, max(estrDates), 0));
yearly_dates = following_day_convention(settlement, 0, 0, 1, longest_mat_years, true);
missing_dates = setdiff(yearly_dates, estrDates); 
missing_rates = interp1(estrDates, estrRates, missing_dates, 'spline');
all_dates = [estrDates; missing_dates(:)];
all_rates = [estrRates; missing_rates(:)];
[estrDates, sort_idx] = sort(all_dates);
estrRates = all_rates(sort_idx);

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

discountCurve = struct('discounts', discounts, 'dates', estrDates);

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

used_futures_idx = idx_3x6;

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

    [pseudo_dates, sort_idx] = sort(pseudo_dates);
    pseudo_discounts = pseudo_discounts(sort_idx);

    used_futures_idx = [used_futures_idx; idx_future];
end    

futures_starts(used_futures_idx) = [];
futures_ends(used_futures_idx) = [];
futures_rates(used_futures_idx) = [];

% 4) Forward step with remaining futures (>6m discounts)

% Identify first swap available (minimum 2Y)
swaps_dates = euriborSet.datesSet.swaps;
idx_swaps = find(swaps_dates >= increment_date(settlement, 0, 11, 1));
swaps_dates = swaps_dates(idx_swaps);
swaps_rates = euriborSet.ratesSet.swaps(idx_swaps);

first_swap_maturity = swaps_dates(1);

if isempty(first_swap_maturity)
    first_swap_maturity = inf; 
end


for i = 1:length(futures_starts)

    start_future = futures_starts(i);
    end_future = futures_ends(i);
    rate_future = futures_rates(i);

    
    if end_future >= first_swap_maturity
        break; 
    end

   
    if pseudo_dates(end) >= end_future
        continue;
    end

    if start_future > pseudo_dates(end)
        break; 
    end


    discount_start = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
        start_future, pseudo_dates, pseudo_discounts);

    delta = yearfrac(start_future, end_future, 2); % ACT/360
    discount_end = discount_start / (1 + delta * rate_future);

    pseudo_dates = [pseudo_dates; end_future];
    pseudo_discounts = [pseudo_discounts; discount_end];

    [pseudo_dates, sort_idx] = sort(pseudo_dates);
    pseudo_discounts = pseudo_discounts(sort_idx);
end


% 5) Swaps (minimum >2Y discount) 
I_prev = 0; 

for i = 1:length(swaps_dates)
    swap_date = swaps_dates(i);
    swap_rate = swaps_rates(i);
   
    years = round(yearfrac(settlement, swap_date, 0));
    
    schedule_fixed = following_day_convention(settlement, 0, 0, 1, years, true);
    deltas_fixed = yearfrac(schedule_fixed(1:end-1), schedule_fixed(2:end), 6); 
    discounts_fixed = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
                schedule_fixed(2:end), discountCurve.dates, discountCurve.discounts);
          
    I_curr = swap_rate * sum(deltas_fixed(:) .* discounts_fixed(:));
    RHS = I_curr - I_prev;
    I_prev = I_curr;

 
    schedule_float = following_day_convention(settlement, 0, 3, 0, years*4, true);
    t_prev = schedule_float(1:end-1);
    t_curr = schedule_float(2:end);
    
    discounts_float_prev = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
                t_prev, discountCurve.dates, discountCurve.discounts);
    discounts_float_curr = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
        t_curr, discountCurve.dates, discountCurve.discounts);
            
    T_known = pseudo_dates(end);
    idx_unknown = find(t_curr > T_known);
    
    if isempty(idx_unknown)
        continue; 
    end
    
    sum_PD_prev_unk = sum(discounts_float_prev(idx_unknown));
    sum_PD_curr_unk = sum(discounts_float_curr(idx_unknown));
    
    beta_pwc = (RHS + sum_PD_curr_unk) / sum_PD_prev_unk;
    
    t_start_unk = t_prev(idx_unknown(1));
    pseudo_curr_val = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
        t_start_unk, pseudo_dates, pseudo_discounts);
    
    new_pseudo_dates = t_curr(idx_unknown);
    new_pseudo_discounts = zeros(length(idx_unknown), 1);
    
    for k = 1:length(idx_unknown)
        step_factor = discounts_float_curr(idx_unknown(k)) / (discounts_float_prev(idx_unknown(k)) * beta_pwc);
        pseudo_curr_val = pseudo_curr_val * step_factor;
        new_pseudo_discounts(k) = pseudo_curr_val;
    end
    
    pseudo_dates = [pseudo_dates; new_pseudo_dates(:)];
    pseudo_discounts = [pseudo_discounts; new_pseudo_discounts(:)];
    
    [pseudo_dates, sort_idx] = sort(pseudo_dates);
    pseudo_discounts = pseudo_discounts(sort_idx);
end



pseudoCurve = struct('discounts', pseudo_discounts, 'dates', pseudo_dates);

end