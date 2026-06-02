function pseudoCurves_adj = rebootstrap_convexity_adjustment(euriborSet, estrSet, pseudoCurve_base, gammas, results_const)
% Starting from calibrated MHW parameters, rebootstraps the curves taking
% into account the convexity adjustments on futures. Returns as struct the
% bootstrapped pseudo-discounting curves with different values of gamma.
% Prints and plots the differences with respect to the unadjusted curve.
%
% INPUTS:
%   euriborSet          - struct containing Euribor3m rates and dates of
%                         corresponding instruments.
%   estrSet             - struct containing OIS ESTR rates and dates of
%                         corresponding instruments.
%   pseudoCurve_base    - unadjusted pseudo-discounting bootstrapped curve.
%   gammas              - vector of gammas considered in MHW calibration.
%   results_conts       - calibrated MHW parameters for different fixed
%                         gamma values
%
% OUTPUTS:
%   pseudoCurves_adj    - Struct containing rebootstrapped
%                         pseudo-discounting curves with convexity adjustment.


n_gammas = length(gammas);
    
% Initialize results struct
pseudoCurves_adj = struct('gamma', cell(n_gammas, 1), 'curve', cell(n_gammas, 1));
rate_variations = cell(n_gammas, 1);

% Initialize comparison plot
figure;
hold on;
colors = lines(n_gammas); 

for i = 1:n_gammas
    % Extract MHW parameters
    hwParams = struct('a', results_const(i).a, ...
                      'sigma', results_const(i).sigma, ...
                      'gamma', gammas(i));
                  
    % Re-Bootstrap the curve considering convexity adjustment
    [~, current_pseudo] = multi_curve_bootstrap(euriborSet, estrSet, false, hwParams);
    
    % Save results
    pseudoCurves_adj(i).gamma = gammas(i);       
    pseudoCurves_adj(i).curve = current_pseudo; 
    
    % Compute difference (in BPS) in the zerorates between unadjusted and adjusted
    % curves
    rate_variations{i} = (current_pseudo.zeroRates - pseudoCurve_base.zeroRates) * 10000;
    
    % Plot the variations
    eurDates = datetime(pseudoCurve_base.dates, 'ConvertFrom', 'datenum');
    plot(eurDates, rate_variations{i}, 'LineWidth', 2, 'Color', colors(i,:), ...
         'DisplayName', sprintf('\\gamma = %.1f', gammas(i)));
end


ax = gca;
ax.FontName = 'Times New Roman';
ax.FontSize = 14;
grid on;
ax.GridLineStyle = ':';
xlabel('Maturity', 'FontSize', 16, 'FontWeight', 'bold');
ylabel('Variation (bps)', 'FontSize', 16, 'FontWeight', 'bold');
title('Zero Rates Variation vs Unadjusted Curve', 'FontSize', 18, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 14);

xlim([eurDates(1) eurDates(1)+calyears(3)]); 
hold off;

% Print the results
fprintf('\n--- CONVEXITY ADJUSTMENT IMPACT (Max Variation on Short-End) ---\n');
for i = 1:n_gammas
    max_diff_bps = max(abs(rate_variations{i}));
    fprintf('Gamma = %.1f | Max diff vs standard curve: %.4f bps\n', gammas(i), max_diff_bps);
end

end