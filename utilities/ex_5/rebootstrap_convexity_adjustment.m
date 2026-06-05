function pseudoCurves_adj = rebootstrap_convexity_adjustment(euriborSet, estrSet, pseudoCurve_base, gammas, results_const)
% REBOOTSTRAP_CONVEXITY_ADJUSTMENT Starting from calibrated MHW parameters, rebootstraps the curves taking into account the convexity adjustments on futures. 
% Returns as struct the bootstrapped pseudo-discounting curves with different values of gamma. Prints and plots the differences with respect to the unadjusted curve.
%
% INPUTS:
%   euriborSet                 : [Struct] struct containing Euribor3m rates and dates of
%                                         corresponding instruments.
%   estrSet                    : [Struct] struct containing OIS ESTR rates and dates of
%                                         corresponding instruments.
%   pseudoCurve_base           : [Struct] unadjusted pseudo-discounting bootstrapped curve.
%   gammas                     : [Vector] vector of gammas considered in MHW calibration.
%   results_const              : [Struct] calibrated MHW parameters for different fixed
%                                         gamma values.
%
% OUTPUTS:
%   pseudoCurves_adj           : [Struct] Struct containing rebootstrapped pseudo-discounting curves with convexity adjustment:
%                                  - .gamma : gamma value used
%                                  - .curve : rebootstrapped pseudo-discounting curve

n_gammas = length(gammas);
    
% Initialize results struct
pseudoCurves_adj = struct('gamma', cell(n_gammas, 1), 'curve', cell(n_gammas, 1));
rate_variations = cell(n_gammas, 1);

% Initialize comparison plot
figure;
hold on;
colorG1     = [225, 125, 115] / 255;
colorG2     = [220, 160,  50] / 255; 
colorG3     = [ 75, 165, 145] / 255; 
colors      = {colorG1, colorG2, colorG3};
styles      = {'o-', '^-', 'd-'};

for i = 1:n_gammas
    % Extract MHW parameters
    mhwParams = struct('a', results_const(i).a, ...
                      'sigma', results_const(i).sigma, ...
                      'gamma', gammas(i));
                  
    % Re-Bootstrap the curve considering convexity adjustment
    [~, current_pseudo] = multi_curve_bootstrap(euriborSet, estrSet, false, mhwParams);
    
    % Save results
    pseudoCurves_adj(i).gamma = gammas(i);       
    pseudoCurves_adj(i).curve = current_pseudo; 
    
    % Compute difference (in BPS) in the zerorates between unadjusted and adjusted
    % curves
    rate_variations{i} = (current_pseudo.zeroRates - pseudoCurve_base.zeroRates) * 10000;
    
    % Plot the variations
    eurDates = datetime(pseudoCurve_base.dates, 'ConvertFrom', 'datenum');
    plot(eurDates, rate_variations{i}, styles{i}, 'LineWidth', 2.0, 'MarkerSize', 8, ...
         'Color', colors{i}, 'MarkerFaceColor', 'w', ...
         'DisplayName', sprintf('\\gamma = %.1f', gammas(i)));
end

% Plot settings
ax = gca;
ax.FontName = 'Times New Roman';
ax.FontSize = 20;
ax.Box = 'off';
ax.XColor = [0.3 0.3 0.3];
ax.YColor = [0.3 0.3 0.3];
ax.LineWidth = 1.5;
grid on;
ax.GridLineStyle = ':';
ax.GridColor = [0.7 0.7 0.7];
ax.GridAlpha = 0.6;
xlabel('Maturity', 'FontName', 'Times New Roman', 'FontSize', 22, 'FontWeight', 'bold');
ylabel('Variation (bps)', 'FontName', 'Times New Roman', 'FontSize', 22, 'FontWeight', 'bold');
title('Zero Rates Variation vs Unadjusted Curve', 'FontName', 'Times New Roman', 'FontSize', 24, 'FontWeight', 'bold');
xlim([eurDates(1) eurDates(1)+calyears(3)]);
lgd = legend('Location', 'best');
lgd.FontName = 'Times New Roman';
lgd.FontSize = 16; 
lgd.Box = 'on';
lgd.EdgeColor = [0.8 0.8 0.8]; 
lgd.Color = [0.98 0.98 0.98]; 
hold off;

% Print the results
fprintf('\n CONVEXITY ADJUSTMENT IMPACT (Max Variation on Short-End) \n');
fprintf('-------------------------------------------------------------\n');
for i = 1:n_gammas
    max_diff_bps = max(abs(rate_variations{i}));
    fprintf(' Gamma = %.1f | Max diff vs standard curve: %.4f bps\n', gammas(i), max_diff_bps);
end

end