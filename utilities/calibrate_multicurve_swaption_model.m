function [results_const, results_pwc, mkt_prices] = calibrate_multicurve_swaption_model(settlement, discountCurve, pseudoCurve, vol_data, diag_expiries, diag_tenors, gammas)
% Calibrates MHW (multi-curve Hull-White) parameters [a, sigma], via 
% Swaptions, given set of fixed values of gamma and a chosen diagonal of
% expiries and tenors.
%
%   1) Starting from implied volatilities of Swaptions under Bachelier (normal)
%   model, reconstruncts market prices. 
%   2) Calibrates MHW parameters in two scenarios: 
%       a) Constant parameters
%       b) Piecewise constant sigma (time dependent)
%
% INPUTS:
%   settlement      - settlement date.
%   discountCurve   - struct containing discount factors, zero-rates, 
%                     and dates for the OIS curve.
%   pseudoCurve     - struct containing discount factors, zero-rates, 
%                     and dates for the Euribor curve.
%   vol_data        - struct containing swaption volatility matrix, 
%                     strike, expiries, and tenors.
%   diag_expiries   - vector of expiries for the chosen diagonal.
%   diag_tenors     - vector of tenors for the chosen diagonal.
%   gammas          - vector of fixed gamma values.
%
% OUTPUTS:
%   results_const   - struct containing calibrated parameters (a, sigma),
%                     gamma, resnorm and model prices for constant volatility.
%   results_pwc     - struct containing calibrated parameters (a_fixed, sigmas),
%                     gamma, SSE, and model prices for piecewise constant volatility.
%   mkt_prices      - vector of reconstructed market prices for the diagonal.

% Extract volatility data
vol_matrix = vol_data.vol_matrix;
strike = vol_data.strike;
expiries = vol_data.expiries;
tenors = vol_data.tenors;

%% COMPUTING MARKET PRICES VIA BACHELIER MODEL

n_swaptions = length(diag_expiries);
mkt_vols = zeros(n_swaptions, 1);

% Find requested swaptions expiries and tenors
for i = 1:n_swaptions
    % Exctract current swaption expiry and tenor
    expiry = diag_expiries(i);
    tenor = diag_tenors(i);
    
    % Find corresponding swaption in the volatility matrix and eventually
    % raise an error if not found
    idx_row = find(expiries == expiry, 1);
    idx_col = find(tenors == tenor, 1);
    if isempty(idx_row) || isempty(idx_col)
        error('Volatility data for Swaption %gY%gY not found.', expiry, tenor)
    end
    mkt_vol = vol_matrix(idx_row, idx_col);
    mkt_vols(i) = mkt_vol;
end    

% From implied volatilities, compute swaption price via Bachelier model
mkt_prices = price_swaption_bachelier(settlement, discountCurve, pseudoCurve, ...
    strike, diag_expiries, diag_tenors, mkt_vols);

%% CALIBRATION WITH CONSTANT PARAMETERS
% Consider globally fixed "a" and sigma parameters.

results_const = struct();
options = optimoptions('lsqnonlin', 'Display', 'off');
   
% Define initial guesses, lower and upper bounds
x0_const = [0.05, 0.01]; % [a, sigma]
lb_const = [1e-6, 1e-6]; 
ub_const = [1.0, 1.0];

% To save optimal values of "a"
best_params_a = zeros(length(gammas), 1);

fprintf('CALIBRATING CONSTANT PARAMETERS ...\n');
for i = 1:length(gammas)
    % Current gamma
    gamma = gammas(i);
    
    % Define objective function (residuals)
    obj_fun = @(p) const_residuals(settlement, p(1), p(2), gamma, ...
        diag_expiries, diag_tenors, strike, discountCurve, pseudoCurve, mkt_prices);
        
    % Optimization
    [best_params_const, resnorm_const, residuals_const] = lsqnonlin(obj_fun, x0_const, lb_const, ub_const, options);
    
    % Save optimal values of "a"
    best_params_a(i) = best_params_const(1); 
    
    % Save results
    results_const(i).gamma = gamma;
    results_const(i).a = best_params_const(1);
    results_const(i).sigma = best_params_const(2);
    results_const(i).resnorm = resnorm_const; 
    results_const(i).model_prices = residuals_const + mkt_prices; 
    
    fprintf('Fixed Gamma = %.1f: a = %.4f%%, sigma = %.4f%% (resnorm = %e)\n', ...
        gamma, best_params_const(1)*100, best_params_const(2)*100, resnorm_const);
end


%% CALIBRATION WITH PIECEWISE CONSTANT SIGMA (TIME DEPENDENT)
% Fix "a" parameter as the one found in previous calibration, now calibrate
% again sigma, not global as before, but instead as piecewise constant.
% Result is a sigmas vector with each calibrated value corresponding to
% each expiry length.

results_pwc = struct();
options = optimoptions('lsqnonlin', 'Display', 'off');
    
% Define initial guess, lower and upper bound
x0_pwc = 0.01 * ones(1, n_swaptions); 
lb_pwc = 1e-6 * ones(1, n_swaptions); 
ub_pwc = 1 * ones(1, n_swaptions);

fprintf('\n CALIBRATING WITH PIECEWISE CONSTANT SIGMA (TIME DEPENDENT)... \n');

for i = 1:length(gammas)
    % Current gamma
    gamma = gammas(i);
    % Fix previously found "a" parameter
    a_fixed = best_params_a(i); 
    
    % Define objective function (residuals)
    obj_fun_pwc = @(p) pwc_residuals(settlement, a_fixed, p, gamma, diag_expiries, ...
                    diag_tenors, strike, discountCurve, pseudoCurve, mkt_prices);
        
    % Optimization
    [best_sigmas, resnorm_pwc, residuals_pwc] = lsqnonlin(obj_fun_pwc, x0_pwc, lb_pwc, ub_pwc, options);
    
    % Save results
    results_pwc(i).gamma = gamma;
    results_pwc(i).a = a_fixed;
    results_pwc(i).sigmas = best_sigmas; 
    results_pwc(i).SSE = resnorm_pwc; 
    results_pwc(i).model_prices = residuals_pwc + mkt_prices; 
    
    fprintf('Fixed Gamma = %.1f and a = %.4f%%: Mean Sigma = %.4f%% (resnorm = %e)\n', ...
        gamma, a_fixed*100, mean(best_sigmas)*100, resnorm_pwc);
end


%% PLOTS

colors = {[0 0.4470 0.7410], [0.9290 0.6940 0.1250], [0.4940 0.1840 0.5560]};
styles = {'o--', '^--', 'd--'}; 

% PLOT CONSTANT PARAMETERRS
figure('Name', 'MHW Calibration - Constant Sigma', 'Color', 'w');
hold on; grid on;
plot(diag_expiries, mkt_prices * 100, 's-', 'LineWidth', 2, 'MarkerSize', 8, ...
    'Color', [0.8500 0.3250 0.0980], 'DisplayName', 'Market');
    
for i = 1:length(gammas)
    plot(diag_expiries, results_const(i).model_prices * 100, styles{i}, ...
        'LineWidth', 1.5, 'MarkerSize', 6, 'Color', colors{i}, ...
        'DisplayName', sprintf('MHW (\\gamma = %.1f)', gammas(i)));
end
xlabel('Expiries (Years)');
ylabel('Swaption Prices (%)');
title('Market vs MHW Model (Constant Volatility)');
legend('Location', 'southoutside', 'NumColumns', 4);
hold off;

% PLOT PIECEWISE CONSTANT SIGMA
figure('Name', 'MHW Calibration - Piecewise Constant', 'Color', 'w');
hold on; grid on;
plot(diag_expiries, mkt_prices * 100, 's-', 'LineWidth', 2, 'MarkerSize', 8, ...
    'Color', [0.8500 0.3250 0.0980], 'DisplayName', 'Market');
    
for i = 1:length(gammas)
    plot(diag_expiries, results_pwc(i).model_prices * 100, styles{i}, ...
        'LineWidth', 1.5, 'MarkerSize', 6, 'Color', colors{i}, ...
        'DisplayName', sprintf('MHW (\\gamma = %.1f)', gammas(i)));
end
xlabel('Expiries (Years)');
ylabel('Swaption Prices (%)');
title('Market vs MHW Model (Piecewise Constant Volatility)');
legend('Location', 'southoutside', 'NumColumns', 4);
hold off;

end


%% HELPERS

% Objective residuals function with constant parameters
function residuals = const_residuals(settlement, a, sigma, gamma, expiries, tenors, strike, discCurve, pseudoCurve, target_prices)
    n = length(expiries);
    model_prices = zeros(n, 1);

    for i = 1:n
        % Compute MHW model prices
        model_prices(i) = price_swaption_MHW(settlement, a, sigma, gamma, expiries(i), tenors(i), strike, discCurve, pseudoCurve);
    end
    
    % Compute residuals
    residuals = model_prices - target_prices;
end

% Objective residuals function with piecewise constant sigma
function residuals = pwc_residuals(settlement, a, sigmas, gamma, expiries, tenors, strike, discCurve, pseudoCurve, target_prices)

n = length(expiries);
model_prices = zeros(n, 1);
T = [0; expiries(:)]; 

% Cycle between expiries
for i = 1:n
    var_i = 0;
    T_i = T(i+1); 
    
    % Consider previous expiry dates
    for k = 1:i
        % Compute cumulated variance
        if a < 1e-6
            term = T(k+1) - T(k);
        else
            term = (exp(-2 * a * (T_i - T(k+1))) - exp(-2 * a * (T_i - T(k)))) / (2 * a);
        end
        var_i = var_i + (sigmas(k)^2) * term;
    end

    % Find correct sigma producing the same observed cumulated variance
    if a < 1e-6
        sigma_eq = sqrt(var_i / T_i);
    else
        sigma_eq = sqrt(var_i * 2 * a / (1 - exp(-2 * a * T_i)));
    end
    
    % Compute MHW model prices
    model_prices(i) = price_swaption_MHW(settlement, a, sigma_eq, gamma, expiries(i), tenors(i), strike, discCurve, pseudoCurve);
end

% Compute residuals
residuals = model_prices - target_prices;

end