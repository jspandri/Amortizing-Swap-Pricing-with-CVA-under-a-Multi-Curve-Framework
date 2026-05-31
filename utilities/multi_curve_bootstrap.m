function [discountCurve, pseudoCurve] = multi_curve_bootstrap(euriborSet, estrSet)
% Performs dual-curve (discount and pseudo-discount curves) bootstrap with 
% crab approach. Requires OIS ESTR and Euribor3m instruments.
% Returns discounting (ESTR) and pseudo-discounting (Euribor3m) curves
% as a struct containing discount factors, zero-rates and corresponding
% dates.
%
% INPUTS:
%   euriborSet          - struct containing Euribor3m rates and dates of
%                         corresponding instruments.
%   estrSet             - struct containing OIS ESTR rates and dates of
%                         corresponding instruments.
%
% OUTPUTS:
%   discountCurve       - struct of discounting (OIS ESTR) curve 
%                         containing discount factors, zero-rates and
%                         corresponding dates.
%   pseudoCurve         - struct of pseudo-discounting (Euribor3m) curve 
%                         containing discount factors, zero-rates and
%                         corresponding dates.

% Extract settlement date
settlement = estrSet.settlement;

%% DISCOUNTING CURVE (OIS ESTR Curve)

% Extract ESTR dates and rates
estrDates = estrSet.dates;
estrRates = estrSet.rates;

% Spline interpolate yearly market rates (to always have yearly rates available
% and avoiding DFs extrapolation)
longest_mat_years = round(yearfrac(settlement, max(estrDates), 0));
yearly_dates = following_day_convention(settlement, 0, 0, 1, longest_mat_years, true);

% Find missing yearly dates and spline interpolate their market rates
missing_dates = setdiff(yearly_dates, estrDates); 
if ~isempty(missing_dates)
    missing_rates = interp1(estrDates, estrRates, missing_dates, 'spline');
    
    % Sort and add to all the rates available
    all_dates = [estrDates; missing_dates(:)];
    all_rates = [estrRates; missing_rates(:)];
    [estrDates, sort_idx] = sort(all_dates);
    estrRates = all_rates(sort_idx);
end

% Define 1 year target to distinguish between rates <= 1Y and >1Y
target_1y = yearly_dates(1);
idx_below_1y = (estrDates <= target_1y);
idx_above_1y = find(~idx_below_1y);

discounts = zeros(length(estrDates), 1);
deltas = yearfrac(settlement, estrDates, 2);

% CASE <= 1Y
% Compute discounts
discounts(idx_below_1y) = 1 ./ (1 + deltas(idx_below_1y) .* estrRates(idx_below_1y));

% CASE > 1Y (to address yearly exchanges)
% Pre-compute deltas
yearly_discounts = zeros(length(yearly_dates), 1);
yearly_discounts(1) = discounts(estrDates == target_1y);
yearly_prev = [settlement; yearly_dates(1:end-1)];
yearly_deltas = yearfrac(yearly_prev, yearly_dates, 2); % ACT/360

for i = 1:length(idx_above_1y)
    idx = idx_above_1y(i);
    T = estrDates(idx);
    R_estr = estrRates(idx);

    % Define if it is a full years maturity 
    is_full_year = (yearly_dates == T);
    
    % If maturity is on yearly dates >1Y (ex. 2Y, 3Y...)
    if any(is_full_year)
        % Extract only past known discounts and deltas
        valid_dates = (yearly_dates < T);
        discounts_k = yearly_discounts(valid_dates);
        deltas_k = yearly_deltas(valid_dates);   
        
        % Compute fixed leg and last delta_i
        fixed_leg = sum(deltas_k(:) .* discounts_k(:));
        last_date = yearly_dates(valid_dates);
        last_date = last_date(end);
        delta_i = yearfrac(last_date, T, 2) ;% ACT/360  
        
        % Compute discount at T
        discount = (1 - R_estr * fixed_leg) / (1 + delta_i * R_estr);

        % Save into yearly_discounts for next iterations
        yearly_discounts(is_full_year) = discount;
    
    % If maturity not on yearly dates (ex. 18m)
    else
        % Need to generate a schedule of payment dates with stub in advance
        schedule = generate_schedule_with_stub(settlement, T);
        % Compute deltas
        t_prev = schedule(1:end-2);
        t_curr = schedule(2:end-1);
        deltas_k = yearfrac(t_prev, t_curr, 2); % ACT/360
        
        % Extract only past known dates and discounts 
        t_known = estrDates(1:idx-1);
        discounts_known = discounts(1:idx-1);
        
        % Interpolate DFs
        discounts_k = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
                      t_curr, t_known, discounts_known);

        % Compute fixed leg and last delta_i
        fixed_leg = sum(deltas_k(:) .* discounts_k(:));
        delta_i = yearfrac(schedule(end-1), schedule(end), 2); % ACT/360

        % Compute discount at T
        discount = (1 - R_estr * fixed_leg) / (1 + delta_i * R_estr);
    end
    discounts(idx) = discount;
end

% Compute zerorates
estrZerorates = from_discount_factors_to_zero_rates(settlement, estrDates, discounts);

% Save discounting curve into a struct
discountCurve = struct('discounts', discounts, 'zeroRates', estrZerorates, 'dates', estrDates);

%% PSEUDO-DISCOUNTING CURVE (Euribor3m curve)

% 1) 3m DEPO (3m discount)

% Extract depo data
depo_dates = euriborSet.datesSet.depos;
depo_rates = euriborSet.ratesSet.depos;

% Find Depo 3m
idx_depo_3m = find(depo_dates == following_day_convention(settlement, 0, 3, 0, 1, true));

if isempty(idx_depo_3m)
    error("No 3 months depo found.");
end

depo_date = depo_dates(idx_depo_3m);
depo_rate = depo_rates(idx_depo_3m);

% Compute discount
delta = yearfrac(settlement, depo_date, 2); % ACT/360
depo_discount = 1 / (1 + delta * depo_rate);

pseudo_dates = [settlement; depo_date];
pseudo_discounts = [1; depo_discount];



% 2) 3x6 Future (6m discount)

% Extract futures data
futures_starts = euriborSet.datesSet.futures(:, 1);
futures_ends = euriborSet.datesSet.futures(:, 2);
futures_rates = euriborSet.ratesSet.futures;

% Find future 3x6
idx_3x6 = find_future_idx(settlement, futures_starts, 3);
start_3x6 = futures_starts(idx_3x6);
end_3x6 = futures_ends(idx_3x6);
rate_3x6 = futures_rates(idx_3x6);

% Discount at 3m
discount_start = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
               start_3x6, pseudo_dates, pseudo_discounts);

% Compute discount at 6m
delta = yearfrac(start_3x6, end_3x6, 2); % ACT/360
discount_end = discount_start / (1 + delta * rate_3x6);

pseudo_dates = [pseudo_dates; end_3x6];
pseudo_discounts = [pseudo_discounts; discount_end];

% Save index to discard later
used_futures_idx = idx_3x6;


% 3) Backward step: 1x4 and 2x5 futures (1m and 2m discounts)

for i = 1:2
    % Find future
    idx_future = find_future_idx(settlement, futures_starts, i);
    start_future = futures_starts(idx_future);
    end_future = futures_ends(idx_future);
    rate_future = futures_rates(idx_future);

    % Discount at future maturity
    discount_end = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
                   end_future, pseudo_dates, pseudo_discounts);

    % Compute discount at future start
    delta = yearfrac(start_future, end_future, 2); % ACT/360
    discount_start = discount_end * (1 + delta * rate_future);

    pseudo_dates = [pseudo_dates; start_future];
    pseudo_discounts = [pseudo_discounts; discount_start];

    % Sort
    [pseudo_dates, sort_idx] = sort(pseudo_dates);
    pseudo_discounts = pseudo_discounts(sort_idx);

    % Save index to discard later
    used_futures_idx = [used_futures_idx; idx_future];
end    

% Remove already used futures 
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

% Set to inf if not available 
if isempty(first_swap_maturity)
    first_swap_maturity = inf; 
end

for i = 1:length(futures_starts)
    % Extract future data
    start_future = futures_starts(i);
    end_future = futures_ends(i);
    rate_future = futures_rates(i);

    % BREAK if coverage over the first swap selected or if futures starts
    % where curve has not been previously covered (to avoid extrapolation)
    if end_future >= first_swap_maturity || start_future > pseudo_dates(end)
        break; 
    end

    % SKIP if curve has already been covered at future maturity
    if pseudo_dates(end) >= end_future
        continue;
    end

    % Discount at future start
    discount_start = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
        start_future, pseudo_dates, pseudo_discounts);

    % Compute discount at future maturity
    delta = yearfrac(start_future, end_future, 2); % ACT/360
    discount_end = discount_start / (1 + delta * rate_future);

    pseudo_dates = [pseudo_dates; end_future];
    pseudo_discounts = [pseudo_discounts; discount_end];

    % Sort
    [pseudo_dates, sort_idx] = sort(pseudo_dates);
    pseudo_discounts = pseudo_discounts(sort_idx);
end


% 5) Swaps (minimum >2Y discount) 

% Pre-compute schedules, deltas and known discounts
longest_swap_years = round(yearfrac(settlement, max(swaps_dates), 0));
% Fixed leg
full_schedule_fixed = [settlement; following_day_convention(settlement, 0, 0, 1, ...
                        longest_swap_years, true)];
full_deltas_fixed = yearfrac(full_schedule_fixed(1:end-1), full_schedule_fixed(2:end), 6); %30/360
full_discounts_fixed = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
    full_schedule_fixed(2:end), discountCurve.dates, discountCurve.discounts);
% Floating leg
full_schedule_float = [settlement; following_day_convention(settlement, 0, 3, 0, ...
                        longest_swap_years*4, true)];
full_t_prev_float = full_schedule_float(1:end-1);
full_t_curr_float = full_schedule_float(2:end);
full_discounts_float = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
    full_schedule_float, discountCurve.dates, discountCurve.discounts);
full_discounts_float_prev = full_discounts_float(1:end-1);
full_discounts_float_curr = full_discounts_float(2:end);

%Compute previous year fixed leg to allow iterative computation of next
%swaps through beta piecewise constant

% Find last known dates and discounts
last_future_date = pseudo_dates(end);
idx_known = find(full_t_curr_float <= last_future_date);
num_quarters_known = length(idx_known);
schedule_float_known = full_schedule_float(1 : num_quarters_known + 1);

deltas_float_known = yearfrac(full_t_prev_float(1:num_quarters_known), full_t_curr_float(1:num_quarters_known), 2);
pseudo_disc = get_discount_factor_by_zero_rates_linear_interp(settlement, schedule_float_known, ... 
                pseudo_dates, pseudo_discounts);
pseudo_prev = pseudo_disc(1:end-1);
pseudo_curr = pseudo_disc(2:end);

% Compute fixed leg (= floating leg by NPV)
L_k = (pseudo_prev ./ pseudo_curr - 1) ./ deltas_float_known;
float_leg = deltas_float_known .* L_k .* full_discounts_float_curr(1:num_quarters_known);
I_prev = sum(float_leg);

% Now start to bootstrap using available swap rates
for i = 1:length(swaps_dates)
    % Extract current swap rate
    swap_rate = swaps_rates(i);
    years = round(yearfrac(settlement, swaps_dates(i), 0));

    % FIXED LEG
    % Extract deltas and discounts
    deltas_fixed = full_deltas_fixed(1:years);
    discounts_fixed = full_discounts_fixed(1:years);

    % Compute fixed leg and the difference with previous year
    I_curr = swap_rate * sum(deltas_fixed(:) .* discounts_fixed(:));
    I_diff = I_curr - I_prev;
    I_prev = I_curr;

    % FLOATING LEG
    % Extract current dates
    num_quarters = (years) * 4;
    t_curr = full_t_curr_float(1:num_quarters);

    % Determine unknown dates
    T_known = pseudo_dates(end);
    idx_unknown = find(t_curr > T_known);

    % SKIP if all dates known
    if isempty(idx_unknown)
        continue; 
    end

    % Extract discounts
    discounts_float_prev = full_discounts_float_prev(idx_unknown);
    discounts_float_curr = full_discounts_float_curr(idx_unknown);

    % Compute beta (spread) assuming piecewise constant during the year
    sum_prev_discounts = sum(discounts_float_prev);
    sum_curr_discounts = sum(discounts_float_curr);
    beta = (I_diff + sum_curr_discounts) / sum_prev_discounts;

    % Compute intermediate quarterly discounts
    % Extract first unknown date
    t_start = full_t_prev_float(idx_unknown(1));
    if t_start == pseudo_dates(end)
        pseudo_curr = pseudo_discounts(end);
    else
        pseudo_curr = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
            t_start, pseudo_dates, pseudo_discounts);
    end

    new_pseudo_dates = t_curr(idx_unknown);
    new_pseudo_discounts = zeros(length(idx_unknown), 1);

    for k = 1:length(idx_unknown)
        % Compute forward pseudo-discount from definition of beta
        pseudo_forward = discounts_float_curr(k) / (discounts_float_prev(k) * beta);
        % Compute current pseudo-discount
        pseudo_curr = pseudo_curr * pseudo_forward;
        new_pseudo_discounts(k) = pseudo_curr;
    end

    pseudo_dates = [pseudo_dates; new_pseudo_dates(:)];
    pseudo_discounts = [pseudo_discounts; new_pseudo_discounts(:)];

    %Sort
    [pseudo_dates, sort_idx] = sort(pseudo_dates);
    pseudo_discounts = pseudo_discounts(sort_idx);
end


% Compute zerorates
euriborZerorates = from_discount_factors_to_zero_rates(settlement, pseudo_dates, pseudo_discounts);

% Save pseudo-discounting curve into a struct
pseudoCurve = struct('discounts', pseudo_discounts(2:end), 'zeroRates', euriborZerorates(2:end), 'dates', pseudo_dates(2:end));


%% PLOT

figure;

eurDates  = datetime(pseudoCurve.dates, 'ConvertFrom', 'datenum');
estrDates = datetime(discountCurve.dates, 'ConvertFrom', 'datenum');

plot(eurDates, pseudoCurve.zeroRates,  'LineWidth', 1.5);
hold on;

plot(estrDates, discountCurve.zeroRates, 'LineWidth', 1.5);

grid on;
zoom on;

xlabel('Date');
ylabel('Zero Rate');
title('EURIBOR3M vs OIS ESTR Zero Rates');

legend('EURIBOR3M', 'OIS ESTR', 'Location', 'best');

end