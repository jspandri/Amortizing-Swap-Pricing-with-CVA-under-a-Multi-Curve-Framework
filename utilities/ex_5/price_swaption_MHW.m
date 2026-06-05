function price_MHW = price_swaption_MHW(settlement, a, sigma, gamma, expiry, tenor, strike, discountCurve, pseudoCurve)
% PRICE_SWAPTION_MHW Price cash-settled swaptions via MHW (Multi-curve Hull-White) model.
%
%
% INPUTS:
%   settlement                 : [Scalar] settlement date.
%   a                          : [Scalar] mean reversion parameter.
%   sigma                      : [Scalar] volatility parameter.
%   gamma                      : [Scalar] gamma parameter.
%   expiry                     : [Scalar] swaption expiry (in years).
%   tenor                      : [Scalar] swap tenor (in years).
%   strike                     : [Scalar] strike value.
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
%   price_MHW                  : [Scalar] computed swaption price.
% Extract discount factors and corresponding dates
discounts = discountCurve.discounts;
dates = discountCurve.dates;

% Pre-compute dates, schedules and discounts
% At expiry 
expiry_date = following_day_convention(settlement, 0, mod(expiry*12, 12), floor(expiry), 1, true);
t_alpha = yearfrac(settlement, expiry_date, 3); % Act/365
discount_expiry = get_discount_factor_by_zero_rates_linear_interp(settlement, expiry_date, dates, discounts);
% Fixed leg
schedule_fixed = [expiry_date; following_day_convention(expiry_date, 0, 0, 1, tenor, true)];
t_fixed = yearfrac(settlement, schedule_fixed, 3);
delta_fixed = yearfrac(schedule_fixed(1:end-1), schedule_fixed(2:end), 6); % 30/360
discounts_fixed = get_discount_factor_by_zero_rates_linear_interp(settlement, schedule_fixed(2:end), dates, discounts);
discount_alpha_j = discounts_fixed ./ discount_expiry;
% Floating leg
schedule_float = [expiry_date; following_day_convention(expiry_date, 0, 3, 0, tenor * 4, true)];
t_float = yearfrac(settlement, schedule_float, 3);
discounts_float = get_discount_factor_by_zero_rates_linear_interp(settlement, schedule_float, dates, discounts);
pseudo_disc_float  = get_discount_factor_by_zero_rates_linear_interp(settlement, schedule_float, pseudoCurve.dates, pseudoCurve.discounts);

% Forward discounts for floating leg
discount_alpha_i_full = discounts_float ./ discount_expiry;
fwd_discounts = discounts_float(2:end) ./ discounts_float(1:end-1);
fwd_pseudo_disc  = pseudo_disc_float(2:end)  ./ pseudo_disc_float(1:end-1);
% Initial forward spreads
beta_i = fwd_discounts ./ fwd_pseudo_disc;


% MHW Volatilities

% Cumulated volatility at expiry
if a < 1e-6
    zeta_alpha = sigma * sqrt(t_alpha);
else
    zeta_alpha = sigma * sqrt((1 - exp(-2 * a * t_alpha)) / (2 * a));
end

% Fixed leg volatilities
v_fix = zeta_alpha * (1 - exp(-a * (t_fixed(2:end) - t_alpha))) / a;
sigma_fix = (1 - gamma) * v_fix;

% Floating leg volatilities
v_float = zeta_alpha * (1 - exp(-a * (t_float - t_alpha))) / a;
% Extended volatilities
nu_i = v_float(1:end-1) - gamma * v_float(2:end); 
sigma_float = (1 - gamma) * v_float(2:end);

discount_alpha_i_start = discount_alpha_i_full(1:end-1); 
discount_alpha_i_end   = discount_alpha_i_full(2:end);  


% Jamshidian approach

% Numerator of the simulated forward swap rate (Floating leg NPV)
N_x = @(x) sum( (discount_alpha_i_start .* beta_i) .* exp(-nu_i * x - 0.5 * nu_i.^2), 1 ) ...
         - sum( discount_alpha_i_end .* exp(-sigma_float * x - 0.5 * sigma_float.^2), 1 );
% Denominator of the simulated forward swap rate (Fixed leg BPV)
D_x = @(x) sum( (delta_fixed .* discount_alpha_j) .* exp(-sigma_fix * x - 0.5 * sigma_fix.^2), 1 );
% Simulated forward swap rate S(x)
S_x = @(x) N_x(x) ./ D_x(x);

% Find x value for which S(x) = strike
x_star = fzero(@(x) N_x(x) - strike * D_x(x), 0);

% Define integrand
integrand = @(x) (1 / sqrt(2*pi)) * exp(-0.5 * x.^2) ...
               .* cash_annuity(S_x(x), tenor) ...
               .* (strike - S_x(x));
    
% Compute receiver swaption price under MHW model
price_MHW = discount_expiry * integral(integrand, -10, x_star);
end

%% HELPER FUNCTION
function C = cash_annuity(S, tenor)
    C = zeros(size(S));
    idx_zero = abs(S) <= 1e-8;
    idx_norm = ~idx_zero;
    
    C(idx_zero) = tenor;
    C(idx_norm) = (1 ./ S(idx_norm)) .* (1 - 1 ./ (1 + S(idx_norm)).^tenor);
end