function floating_leg_spread_beta = compute_floating_leg_spread_beta(...
    start_date, payment_dates, ois_curve, eur_curve)
% COMPUTE_FLOATING_LEG_SPREAD_BETA Computates multi-curve floating adjustment 
% factors (betas).
%
% This function calculates the deterministic ratio (beta) between the market 
% forward discount factors computed under the Euribor (pseudo discounting) 
% curve and the OIS (discounting) curve. These betas are utilized within the
% multi-curve framework to adjust the tree valuation of the floating leg without 
% introducing additional variables.
%
% INPUTS:
%   start_date    : [Datenum] Valuation date t0.
%   payment_dates : [Vector] Payment dates of the swap (Datenum).
%   ois_curve     : [Struct] OIS curve containing:
%                     .dates     : Market pillar dates.
%                     .discounts : Market OIS discount factors.
%   eur_curve     : [Struct] Euribor curve containing:
%                     .dates     : Market pillar dates.
%                     .discounts : Market Euribor discount factors.
%
% OUTPUTS:
%   floating_leg_spread_beta : [Vector] Multi-curve adjustment weights for each period.

    % Extract and convert OIS market curve dates and discounts
    ois_dates = datenum(ois_curve.dates);
    ois_discounts = ois_curve.discounts;
    
    % Extract and convert Euribor market curve dates and discounts
    eur_dates = datenum(eur_curve.dates);
    eur_discounts = eur_curve.discounts;
    
    % 1. BUILD ACCRUAL PERIOD START AND END DATE VECTORS 

    % First period starts at t0 (start_date), subsequent periods start at 
    % previous payment dates
    T_starts = [start_date; payment_dates(1:end-1)];
    T_ends   = payment_dates; 
    
    % 2. EXTRACT SPOT DISCOUNT FACTORS FROM OIS CURVE (Referenced to t0)
    % Interpolate market OIS zero rates to get discounts at period starts and ends
    B_ois_start = get_discount_factor_by_zero_rates_linear_interp(...
                    start_date, T_starts, ois_dates, ois_discounts);
    B_ois_end   = get_discount_factor_by_zero_rates_linear_interp(...
                    start_date, T_ends, ois_dates, ois_discounts);
    
    % Compute the OIS Market Forward discount: 
    % P^D(t0; T_start, T_end) = P^D(t0, T_end) / P^D(t0, T_start)
    B_ois_forward = B_ois_end ./ B_ois_start;
    
    % 3. EXTRACT SPOT DISCOUNT FACTORS FROM EURIBOR CURVE (Referenced to t0)
    % Interpolate market Euribor zero rates to get spot discounts at period starts and ends
    B_eur_start = get_discount_factor_by_zero_rates_linear_interp(...
                    start_date, T_starts, eur_dates, eur_discounts);
    B_eur_end   = get_discount_factor_by_zero_rates_linear_interp(...
                    start_date, T_ends, eur_dates, eur_discounts);
    
    % Compute the Euribor Market Forward discount: 
    % P^F(t0; T_start, T_end) = P^F(t0, T_end) / P^F(t0, T_start)
    B_eur_forward = B_eur_end ./ B_eur_start;
    
    % 4. CALCULATE VECTORIZED BETA FACTOR
    % Ratio between the OIS and Euribor forward market discounts at time t0
    floating_leg_spread_beta = B_ois_forward ./ B_eur_forward;
       
end