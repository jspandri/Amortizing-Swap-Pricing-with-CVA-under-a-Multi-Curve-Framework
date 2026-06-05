function plot_cva_dashboard(payDates, EE_profiles, hazardRates, recoveryRate, settlement, cdsSpreads_bps)
    % PLOT_CVA_DASHBOARD Creates a 4-panel plot
    % showing how Market Risk and Credit Risk combine to form the CVA.
    % It supports multiple hazard rate scenarios for comparative analysis.
    %
    % INPUTS:
    %   payDates       : [Vector] Swap payment dates (datenum).
    %   EE_profiles    : [Matrix] Expected Exposures (N x M), where M is the number of scenarios.
    %   hazardRates    : [Vector] Constant default intensities (length M).
    %   recoveryRate   : [Scalar] Expected recovery rate R.
    %   settlement     : [Scalar] Valuation date (datenum).
    %   cdsSpreads_bps : [Vector] (Optional) Array of CDS spreads in bps for the legend.
    
    num_scenarios = length(hazardRates);
    
    % Default legend labels if CDS spreads are not provided
    if nargin < 6 || isempty(cdsSpreads_bps)
        legend_labels = arrayfun(@(x) sprintf('Hazard Rate: %.2f%%', x*100), hazardRates, 'UniformOutput', false);
    else
        legend_labels = arrayfun(@(x) sprintf('CDS: %d bps', x), cdsSpreads_bps, 'UniformOutput', false);
    end

    % Time Vector Calculation (ACT/365)
    t_years = yearfrac(settlement, payDates, 3);
    
    % Preallocate matrices for probabilities and CVA density
    num_dates = length(payDates);
    SP          = zeros(num_dates, num_scenarios);
    Marginal_PD = zeros(num_dates, num_scenarios);
    CVA_density = zeros(num_dates, num_scenarios);
    
    LGD = 1 - recoveryRate;
    
    % Probabilities and Incremental CVA Calculation
    for i = 1:num_scenarios
        % Survival Probability
        SP(:, i) = exp(-hazardRates(i) * t_years);           
        
        % Marginal Probability of Default
        SP_prev = [1; SP(1:end-1, i)];
        Marginal_PD(:, i) = SP_prev - SP(:, i);                
        
        % Incremental CVA (CVA Density)
        CVA_density(:, i) = EE_profiles(:, i) .* Marginal_PD(:, i) .* LGD;
    end
    
    % Figure Creation
    figure;

    % Colors for the plots 
    colors = [0, 0.4470, 0.7410;   % Deep Blue
              0.8500, 0.3250, 0.0980]; % Orange/Red
    
    pad_days = 15; 
    x_limits = [payDates(1) - pad_days, payDates(end) + pad_days];

    % Panel 1: Expected Exposure 
    subplot(2, 2, 1);
    for i = 1:num_scenarios
        plot(payDates, EE_profiles(:, i), 'LineWidth', 2.5, 'Color', colors(i,:)); hold on;
    end
    xlim(x_limits); 
    datetick('x', 'yyyy', 'keeplimits');
    title('1. Expected Exposure (EE)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Exposure (EUR)');
    legend(legend_labels, 'Location', 'best');
    grid on;
    
    % Panel 2: Survival Probability 
    subplot(2, 2, 2);
    for i = 1:num_scenarios
        plot(payDates, SP(:, i), '-', 'LineWidth', 2.5, 'Color', colors(i,:)); hold on;
    end
    xlim(x_limits); 
    datetick('x', 'yyyy', 'keeplimits');
    title('2. Survival Probability', 'FontSize', 12, 'FontWeight', 'bold');
    legend(legend_labels, 'Location', 'best');
    ylabel('Probability');
    grid on;
    
    % Panel 3: Marginal PD 
    subplot(2, 2, 3);
    b = bar(payDates, Marginal_PD, 'grouped', 'EdgeColor', 'none');
    if num_scenarios <= length(colors)
        for i = 1:num_scenarios
            b(i).FaceColor = colors(i,:);
        end
    end
    xlim(x_limits); 
    datetick('x', 'yyyy', 'keeplimits');
    title('3. Marginal Default Probability', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Probability per node');
    legend(legend_labels, 'Location', 'best');
    grid on;
    
    % Panel 4: CVA Density 
    subplot(2, 2, 4);
    for i = 1:num_scenarios
        a = area(payDates, CVA_density(:, i), 'FaceAlpha', 0.4, 'EdgeColor', colors(i,:), 'LineWidth', 1.5);
        a.FaceColor = colors(i,:);
        hold on;
    end
    xlim(x_limits); 
    datetick('x', 'yyyy', 'keeplimits');
    title('4. Incremental CVA (EE \times PD \times LGD)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('CVA Contribution (EUR)');
    legend(legend_labels, 'Location', 'best');
    grid on;
    
    % General Figure Title
    settlement_str = datestr(settlement, 'dd-mmm-yyyy');
    sgtitle(sprintf('CVA Formation Mechanics | Settlement: %s | Recovery Rate: %.0f%%', ...
        settlement_str, recoveryRate * 100), 'FontSize', 14, 'FontWeight', 'bold');
end