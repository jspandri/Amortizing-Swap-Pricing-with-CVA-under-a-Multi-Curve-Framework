function plot_interpolated_volatility(payDates, vol_data)
    % PLOT_INTERPOLATED_VOLATILITY Plots the equivalent Bachelier 
    % implied volatility extracted for each expiry node.
    % (Excludes the final node where the residual BPV drops to zero).
    %
    % INPUTS:
    %   payDates : [Vector] Option expiry dates (datenum).
    %   vol_data : [Vector] Interpolated normal implied volatilities.
    
    figure('Name', 'Interpolated Bachelier Volatility', 'Position', [150, 150, 800, 450], 'Color', 'w');
    
    % Usa 1:end-1 per tralasciare l'ultimo punto a 0
    plot(payDates(1:end-1), vol_data(1:end-1) * 10000, '-o', 'LineWidth', 2, 'MarkerSize', 5, 'Color', [0.4940, 0.1840, 0.5560]); % Colore Viola
    
    datetick('x', 'yyyy');
    title('Interpolated Bachelier Volatility Profile', 'FontSize', 13, 'FontWeight', 'bold');
    subtitle('Dynamic mapping across the Volatility Cube driven by the amortizing profile');
    xlabel('Option Expiry Date ($t_\alpha$)', 'Interpreter', 'latex', 'FontSize', 11);
    ylabel('Normal Implied Volatility (bps)', 'FontSize', 11);
    
    grid on;
    
    hold on;
    % Applica 1:end-1 anche all'area colorata
    area(payDates(1:end-1), vol_data(1:end-1) * 10000, 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'FaceColor', [0.4940, 0.1840, 0.5560]);
    hold off;
end