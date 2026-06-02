function gamma_tilda = compute_convexity_adjustment(a, sigma, gamma, t_start, t_end)
% Computes the convexity adjustment gamma term for STIR futures (fully vectorized)
% under the Multi-Curve Hull-White (MHW) model.
%
% INPUTS:
%   a                   - HW mean reversion parameter.
%   sigma               - HW volatility parameter.
%   gamma               - MHW spread parameter.
%   t_start             - yearfrac of futures' start date.
%   t_end               - yearfrac of futures' end date.
%
% OUTPUTS:
%   gamma_tilda           - convexity adjustment gamma term.

% Discounting curve volatility
sigma_hat = (1 - gamma) * sigma;

% Convexity adjustment term gamma_1 under S0 hypothesis
ln_gamma_1 = (sigma_hat^2) .* (1 - exp(-a .* (t_end - t_start))) ./ a .* ((1 ...
    - exp(-a .* t_start)) ./ (a^2) - (exp(-a .* (t_end - t_start)) .* (1 ...
    - exp(-2 .* a .* t_start)) ./ (2 * (a^2))));
gamma_1 = exp(ln_gamma_1);

% gamma_tilda convexity adjustment: gamma = 1 + gamma_tilda
% Allows to adjust with approximation: F = F_fut - gamma_tilda / delta
gamma_tilda = gamma_1 - 1;

end