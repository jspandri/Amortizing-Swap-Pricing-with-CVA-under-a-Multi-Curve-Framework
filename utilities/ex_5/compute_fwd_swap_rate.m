function S_fwd = compute_fwd_swap_rate(settlement, expiry, tenor, discountCurve, pseudoCurve)
% COMPUTE_FWD_SWAP_RATE Compute the forward swap rate for a given set of expiries and tenors.
%
% INPUTS:
%   settlement                 : [Scalar] scalar date representing the valuation date.
%   expiry                     : [Scalar/Vector] expiry in years.
%   tenor                      : [Scalar/Vector] tenor in years.
%   discountCurve              : [Struct] struct of discounting (OIS ESTR) curve containing:
%                                  - .discounts : discount factors
%                                  - .zeroRates : zero-rates
%                                  - .dates     : corresponding dates
%   pseudoCurve                : [Struct] struct of pseudo-discounting (Euribor3m) curve containing:
%                                  - .discounts : discount factors
%                                  - .zeroRates : zero-rates
%                                  - .dates     : corresponding dates
%
% OUTPUTS:
%   S_fwd                      : [Vector] vector of computed forward swap rates.

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