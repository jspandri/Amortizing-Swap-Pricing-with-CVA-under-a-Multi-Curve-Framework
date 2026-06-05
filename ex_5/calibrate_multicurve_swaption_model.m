function [results_const, results_pwc, mkt_prices] = calibrate_multicurve_swaption_model(settlement, discountCurve, pseudoCurve, vol_data, diag_expiries, diag_tenors, gammas)
% CALIBRATE_MULTICURVE_SWAPTION_MODEL Calibrates MHW (multi-curve Hull-White) parameters [a, sigma], via Swaptions, given set of fixed values of gamma and a chosen diagonal of expiries and tenors.
%
%   1) Starting from implied volatilities of Swaptions under Bachelier (normal)
%      model, reconstructs market prices. 
%   2) Calibrates MHW parameters in two scenarios: 
%       a) Constant parameters
%       b) Piecewise constant sigma (time dependent)
%
% INPUTS:
%   settlement                 : [Scalar/Datetime] settlement date.
%   discountCurve              : [Struct] struct containing discount factors, zero-rates, and dates for the OIS curve:
%                                  - .discounts  : discount factors
%                                  - .zeroRates  : zero-rates
%                                  - .dates      : dates for the OIS curve
%   pseudoCurve                : [Struct] struct containing discount factors, zero-rates, and dates for the Euribor curve:
%                                  - .discounts  : discount factors
%                                  - .zeroRates  : zero-rates
%                                  - .dates      : dates for the Euribor curve
%   vol_data                   : [Struct] struct containing swaption volatility matrix, strike, expiries, and tenors:
%                                  - .vol_matrix : swaption volatility matrix
%                                  - .strike     : strike
%                                  - .expiries   : expiries
%                                  - .tenors     : tenors
%   diag_expiries              : [Vector] vector of expiries for the chosen diagonal.
%   diag_tenors                : [Vector] vector of tenors for the chosen diagonal.
%   gammas                     : [Vector] vector of fixed gamma values.
%
% OUTPUTS:
%   results_const              : [Struct] struct containing calibrated parameters (a, sigma), gamma, resnorm and model prices for constant volatility:
%                                  - .a            : calibrated parameter a
%                                  - .sigma        : calibrated parameter sigma
%                                  - .gamma        : fixed gamma value
%                                  - .resnorm      : resnorm
%                                  - .model_prices : model prices
%   results_pwc                : [Struct] struct containing calibrated parameters (a_fixed, sigmas), gamma, SSE, and model prices for piecewise constant volatility:
%                                  - .a            : fixed parameter a
%                                  - .sigmas       : calibrated piecewise constant sigmas
%                                  - .gamma        : fixed gamma value
%                                  - .SSE          : sum of squared errors
%                                  - .model_prices : model prices
%   mkt_prices                 : [Vector] vector of reconstructed market prices for the diagonal.

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
ub_const = [100, 100];

% To save optimal values of "a"
best_params_a = zeros(length(gammas), 1);

fprintf('\n CALIBRATING CONSTANT PARAMETERS ...\n');
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
    
    fprintf('Fixed Gamma = %.1f: a = %.4f, sigma = %.4f%% (resnorm = %e)\n', ...
        gamma, best_params_const(1), best_params_const(2)*100, resnorm_const);
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
ub_pwc = inf * ones(1, n_swaptions);

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
    
    fprintf('Fixed Gamma = %.1f and a = %.4f: Mean Sigma = %.4f%% (resnorm = %e)\n', ...
        gamma, a_fixed, mean(best_sigmas)*100, resnorm_pwc);
end


%% PLOTS

colorMarket = [45, 105, 152] / 255; 
colorG1     = [225, 125, 115] / 255;
colorG2     = [220, 160,  50] / 255; 
colorG3     = [ 75, 165, 145] / 255; 
colors      = {colorG1, colorG2, colorG3};
styles      = {'o--', '^--', 'd--'}; 

% CONSTANT PARAMETERS
figure;
hold on; 

plot(diag_expiries, mkt_prices * 100, 's-', 'LineWidth', 2.5, 'MarkerSize', 8, ...
    'Color', colorMarket, 'MarkerFaceColor', colorMarket, 'DisplayName', 'Market');
 
for i = 1:length(gammas)
    plot(diag_expiries, results_const(i).model_prices * 100, styles{i}, ...
        'LineWidth', 2.0, 'MarkerSize', 8, 'Color', colors{i}, ...
        'MarkerFaceColor', 'w', 'DisplayName', sprintf('MHW (\\gamma = %.1f)', gammas(i)));
end

ax = gca;
ax.FontName = 'Times New Roman';
ax.FontSize = 20;
ax.Box = 'off';
ax.XColor = [0.3 0.3 0.3];
ax.YColor = [0.3 0.3 0.3];
ax.LineWidth = 1.5;
ytickformat('%.2f%%'); 

grid on;
ax.GridLineStyle = ':';
ax.GridColor = [0.7 0.7 0.7];
ax.GridAlpha = 0.6;

xlabel('Expiries (Years)', 'FontName', 'Times New Roman', 'FontSize', 22, 'FontWeight', 'bold');
ylabel('Swaption Prices (%)', 'FontName', 'Times New Roman', 'FontSize', 22, 'FontWeight', 'bold');
title('Market vs MHW Model (Constant Parameters)', 'FontName', 'Times New Roman', 'FontSize', 24, 'FontWeight', 'bold');
lgd = legend('Location', 'southoutside', 'NumColumns', 4);
lgd.FontName = 'Times New Roman';
lgd.FontSize = 16; 
lgd.Box = 'on';
lgd.EdgeColor = [0.8 0.8 0.8]; 
lgd.Color = [0.98 0.98 0.98]; 
hold off;

% PLOT PIECEWISE CONSTANT SIGMA
figure;
hold on; 

plot(diag_expiries, mkt_prices * 100, 's-', 'LineWidth', 2.5, 'MarkerSize', 8, ...
    'Color', colorMarket, 'MarkerFaceColor', colorMarket, 'DisplayName', 'Market');
  
for i = 1:length(gammas)
    plot(diag_expiries, results_pwc(i).model_prices * 100, styles{i}, ...
        'LineWidth', 2.0, 'MarkerSize', 8, 'Color', colors{i}, ...
        'MarkerFaceColor', 'w', 'DisplayName', sprintf('MHW (\\gamma = %.1f)', gammas(i)));
end

ax = gca;
ax.FontName = 'Times New Roman';
ax.FontSize = 20;
ax.Box = 'off';
ax.XColor = [0.3 0.3 0.3];
ax.YColor = [0.3 0.3 0.3];
ax.LineWidth = 1.5;
ytickformat('%.2f%%'); 

grid on;
ax.GridLineStyle = ':';
ax.GridColor = [0.7 0.7 0.7];
ax.GridAlpha = 0.6;

xlabel('Expiries (Years)', 'FontName', 'Times New Roman', 'FontSize', 22, 'FontWeight', 'bold');
ylabel('Swaption Prices (%)', 'FontName', 'Times New Roman', 'FontSize', 22, 'FontWeight', 'bold');
title('Market vs MHW Model (Piecewise-Constant Volatility)', 'FontName', 'Times New Roman', 'FontSize', 24, 'FontWeight', 'bold');
lgd = legend('Location', 'southoutside', 'NumColumns', 4);
lgd.FontName = 'Times New Roman';
lgd.FontSize = 16; 
lgd.Box = 'on';
lgd.EdgeColor = [0.8 0.8 0.8]; 
lgd.Color = [0.98 0.98 0.98]; 
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