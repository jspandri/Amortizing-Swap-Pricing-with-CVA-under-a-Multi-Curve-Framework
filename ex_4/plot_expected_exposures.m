function plot_expected_exposures(payDates, EE_1, EE_2, spreads)
% PLOT_EXPECTED_EXPOSURES Plots the Expected Exposure profiles for two different CDS spreads.
%
% INPUTS:
%   payDates     : [Vector] Swap payment dates 
%   EE_1         : [Vector] Expected Exposure profile for the first hazard rate.
%   EE_2         : [Vector] Expected Exposure profile for the second hazard rate.
%   spreads      : [Vector] The CDS spreads used for the legend.
    
    if ~isdatetime(payDates)
        payDates = datetime(payDates, 'ConvertFrom', 'datenum'); 
    end

    figure('Name', 'Expected Exposures', 'Position', [100, 100, 800, 600]);
    
    % Top Subplot: First Spread
    subplot(2, 1, 1);
    plot(payDates, EE_1, '-o', 'LineWidth', 1.5, 'Color', '#0072BD');
    grid on;
    title(sprintf('Expected Exposure (EE) - CDS %d bps', round(spreads(1)*10000)));
    ylabel('Expected Exposure (EUR)');
    
    % Bottom Subplot: Second Spread
    subplot(2, 1, 2);
    plot(payDates, EE_2, '-s', 'LineWidth', 1.5, 'Color', '#D95319');
    grid on;
    title(sprintf('Expected Exposure (EE) - CDS %d bps', round(spreads(2)*10000)));
    xlabel('Payment Dates');
    ylabel('Expected Exposure (EUR)');
end