function mkt_prices = price_swaption_bachelier(settlement, discountCurve, pseudoCurve, strike, expiries, tenors, sigmas)
% PRICE_SWAPTION_BACHELIER Price cash-settled swaptions via Bachelier (normal) 
% model (works with vectors of expiries, tenors and sigmas).
%
%
% INPUTS:
%   settlement                 : [Scalar/Datetime] settlement date.
%   discountCurve              : [Struct] struct of discounting (OIS ESTR) curve containing:
%                                  - .discounts : discount factors
%                                  - .zeroRates : zero-rates
%                                  - .dates     : corresponding dates
%   pseudoCurve                : [Struct] struct of pseudo-discounting (Euribor3m) curve containing:
%                                  - .discounts : discount factors
%                                  - .zeroRates : zero-rates
%                                  - .dates     : corresponding dates
%   strike                     : [Scalar] strike value.
%   expiries                   : [Vector] vector of expiries for the chosen diagonal.
%   tenors                     : [Vector] vector of tenors for the chosen diagonal.
%   sigmas                     : [Vector] vector of implied normal volatilities.
%
% OUTPUTS:
%   mkt_prices                 : [Vector] vector of reconstructed market prices for the diagonal.

% Compute expiry dates and corresponding discounts
expiry_dates = following_day_convention(settlement, 0, mod(expiries*12, 12), floor(expiries), 1, true);
discount_expiries = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
    expiry_dates, discountCurve.dates, discountCurve.discounts);

% Compute forward swap rates
n = length(expiries);
swap_rates = zeros(n, 1);
for i = 1:n
    swap_rates(i) = compute_fwd_swap_rate(settlement, expiries(i), tenors(i), ...
                        discountCurve, pseudoCurve);
end    

% Compute cash annuities with robustness check (division near zero)
cash_annuities = zeros(length(swap_rates), 1);
idx_zero = abs(swap_rates) <= 1e-8;  
idx_norm = ~idx_zero;      
cash_annuities(idx_zero) = tenors(idx_zero); 
cash_annuities(idx_norm) = (1 ./ swap_rates(idx_norm)) .* (1 - 1 ./ (1 + swap_rates(idx_norm)).^tenors(idx_norm));

% Compute Bachelier price (receiver swaption)
t_alphas = yearfrac(settlement, expiry_dates, 3);
d = (swap_rates - strike) ./ (sigmas .* sqrt(t_alphas));

mkt_prices = discount_expiries .* cash_annuities .* ((strike - swap_rates) .* normcdf(-d) ...
    + sigmas .* sqrt(t_alphas) .* normpdf(d));

end