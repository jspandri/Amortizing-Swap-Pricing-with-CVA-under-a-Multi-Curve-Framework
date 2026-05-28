function floating_leg_spread_beta = compute_floating_leg_spread_beta(...
    start_date, fixing_start, fixing_end, ois_curve, eur_curve)
% COMPUTE_FLOATING_LEG_SPREAD_BETA Computes multi-curve floating adjustment
% factors (betas) that are deterministic since we operate under the 'gamma
% = 0' hypothesis
%
% INPUTS:
%   start_date    : [Datenum] Valuation date t0.
%   fixing_start  : [Vector] Start dates for each fixing period (Datenum).
%   fixing_end    : [Vector] End dates for each fixing period (Datenum).
%   ois_curve     : [Struct] OIS curve (.dates, .discounts).
%   eur_curve     : [Struct] Euribor curve (.dates, .discounts).
%
% OUTPUTS:
%   floating_leg_spread_beta : [Vector] Deterministic multi-curve adjustment weights.

    % Extract and convert OIS market curve dates and discounts
    ois_dates = datenum(ois_curve.dates);
    ois_discounts = ois_curve.discounts;
    
    % Extract and convert Euribor market curve dates and discounts
    eur_dates = datenum(eur_curve.dates);
    eur_discounts = eur_curve.discounts;
    
    % 1. EXTRACT SPOT DISCOUNT FACTORS FROM OIS CURVE (Referenced to t0)
    % Interpolate market OIS zero rates to get discounts at fixing period starts 
    % (from the second one to avoid past dates) and ends
    B_ois_start = get_discount_factor_by_zero_rates_linear_interp(...
                    start_date, fixing_start(2:end), ois_dates, ois_discounts);
    
    % The first discount is computed by using the first accrual date (= start date) 
    % since the first fixing start date is before start date
    B_ois_start = [1; B_ois_start];
    
    B_ois_end   = get_discount_factor_by_zero_rates_linear_interp(...
                    start_date, fixing_end, ois_dates, ois_discounts);
    
    % Compute the OIS Market Forward discount: 
    % P^D(t0; T_start, T_end) = P^D(t0, T_end) / P^D(t0, T_start)
    B_ois_forward = B_ois_end ./ B_ois_start;
    
    % 2. EXTRACT SPOT DISCOUNT FACTORS FROM EURIBOR CURVE (Referenced to t0)
    % Interpolate market Euribor zero rates to get spot discounts at fixing period starts 
    % (from the second one to avoid past dates) and ends 
    B_eur_start = get_discount_factor_by_zero_rates_linear_interp(...
                    start_date, fixing_start(2:end), eur_dates, eur_discounts);
    B_eur_end   = get_discount_factor_by_zero_rates_linear_interp(...
                    start_date, fixing_end, eur_dates, eur_discounts);

    % The first discount is computed by using the first accrual date (= start date) 
    % since the first fixing start date is before start date
    B_eur_start = [1; B_eur_start];
        
    % Compute the Euribor Market Forward discount: 
    % P^F(t0; T_start, T_end) = P^F(t0, T_end) / P^F(t0, T_start)
    B_eur_forward = B_eur_end ./ B_eur_start;
    
    % 3. CALCULATE VECTORIZED BETA FACTOR (Deterministic under gamma=0)
    % Under the gamma=0 assumption, the basis is deterministic, allowing us to 
    % define the beta adjustment as the ratio between OIS and Euribor forward 
    % prices as observed at the valuation date t0.
    floating_leg_spread_beta = B_ois_forward ./ B_eur_forward;
       
end