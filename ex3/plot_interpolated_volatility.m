function plot_interpolated_volatility(payDates, vol_data)
    % PLOT_INTERPOLATED_VOLATILITY Plots the equivalent Bachelier 
    % implied volatility extracted for each expiry node.
    % (Excludes the final node where the residual BPV drops to zero).
    %
    % INPUTS:
    %   payDates : [Vector] Option expiry dates (datenum).
    %   vol_data : [Vector] Interpolated normal implied volatilities.
    
    figure;
    colorVol = [100, 180, 210] / 255;  
    expiryDates = datetime(payDates, 'ConvertFrom', 'datenum');
    
    idx = 1:length(vol_data)-1;
    area(expiryDates(idx), vol_data(idx) * 10000, 'FaceAlpha', 0.1, ...
         'EdgeColor', 'none', 'FaceColor', colorVol);
    hold on;
    plot(expiryDates(idx), vol_data(idx) * 10000, '-o', 'LineWidth', 3.0, ...
        'MarkerSize', 6, 'MarkerFaceColor', 'w', 'Color', colorVol);
    
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
    xlabel('Option Expiry Date ($t_\alpha$)', 'FontName', 'Times New Roman', ...
        'FontSize', 22, 'FontWeight', 'bold', 'Interpreter', 'latex');
    ylabel('Normal Vol (bps)', 'FontName', 'Times New Roman', ...
        'FontSize', 22, 'FontWeight', 'bold');
    titleText = sprintf('Bachelier Volatility Profile');
    title(titleText, 'FontName', 'Times New Roman', 'FontSize', 24, 'FontWeight', 'bold');
    zoom on;
end