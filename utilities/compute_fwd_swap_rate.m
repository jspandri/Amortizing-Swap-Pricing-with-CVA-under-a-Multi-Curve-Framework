function S_fwd = compute_fwd_swap_rate(settlement, expiry, tenor, discountCurve, pseudoCurve)
% Compute the forward swap rate for a given set of expiries and tenors.
%
% INPUTS:
%   settlement      - scalar date representing the valuation date.
%   expiry          - expiry in years.
%   tenor           - tenor in years.
%   discountCurve   - struct of discounting (OIS ESTR) curve 
%                     containing discount factors, zero-rates and
%                     corresponding dates.
%   pseudoCurve     - struct of pseudo-discounting (Euribor3m) curve 
%                     containing discount factors, zero-rates and
%                     corresponding dates.
%
% OUTPUTS:
%   S_fwd           - vector of computed forward swap rates.

expiry_date = following_day_convention(settlement, 0, 0, expiry, 1, true);

% Compute schedule, deltas and discounts of fixed leg
schedule_fixed = [expiry_date; following_day_convention(expiry_date, 0, 0, 1, ...
                    tenor, true)];
deltas_fixed = yearfrac(schedule_fixed(1:end-1), schedule_fixed(2:end), 6); % 30/360
discounts_fixed = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
                    schedule_fixed(2:end), discountCurve.dates, discountCurve.discounts);

% Compute BPV
BPV = sum(deltas_fixed .* discounts_fixed);

% Compute schedule, discounts and pseudo discounts of floating leg
schedule_float = [expiry_date; following_day_convention(expiry_date, 0, 3, 0, ...
                    tenor * 4, true)];
pseudo_disc_float = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
    schedule_float, pseudoCurve.dates, pseudoCurve.discounts);
discounts_float = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
    schedule_float(2:end), discountCurve.dates, discountCurve.discounts);
prev_pseudo_disc_float = pseudo_disc_float(1:end-1);
curr_pseudo_disc_float = pseudo_disc_float(2:end);

% Compute the floating leg value
float_leg = sum(((prev_pseudo_disc_float ./ curr_pseudo_disc_float) - 1) .* discounts_float);

% Compute forward swap rate
S_fwd = float_leg / BPV;

end