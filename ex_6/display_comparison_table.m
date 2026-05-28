function comparison_table = display_comparison_table(result_const, result_pwc)
% DISPLAY_COMPARISON_TABLE Generates a comparison table for the highest precision level.
%
% This function extracts the pricing metrics (Risk-Free NPV, CVA, Risky NPV) 
% at the highest tree discretization level (the last element) and compares 
% the Constant Sigma approach with the Piecewise Constant Sigma approach.
%
% INPUTS:
%   result_const : [Struct] Results structure from the Constant Sigma HW model.
%   result_pwc   : [Struct] Results structure from the Piecewise Constant HW model.
%
% OUTPUTS:
%   comparison_table : [Table] Formatted MATLAB table showing the differences.

    % Extract metrics for the highest precision level (last element in the array) for Constant Sigma
    npv_rf_const = result_const.Risk_free_Swap_Price(end);
    cva_const    = result_const.CVA(end);
    npv_risky_const = result_const.Risky_Swap_Price(end);
    
    % Extract metrics for the highest precision level for Piecewise Constant (PWC) Sigma
    npv_rf_pwc = result_pwc.Risk_free_Swap_Price(end);
    cva_pwc    = result_pwc.CVA(end);
    npv_risky_pwc = npv_rf_pwc - cva_pwc;
        
    % Aggregate the column values for Constant Sigma
    Values_Constant_Sigma = [npv_rf_const; cva_const; npv_risky_const];
    
    % Aggregate the column values for Piecewise Constant Sigma
    Values_Piecewise_Constant = [npv_rf_pwc; cva_pwc; npv_risky_pwc];
    
    % Compute the absolute discrepancy between the two approaches
    Absolute_Difference = abs(Values_Constant_Sigma - Values_Piecewise_Constant);
    
    % Compute relative difference as a percentage
    Rel_Diff_Raw = (Absolute_Difference ./ abs(Values_Constant_Sigma)) * 100;
    
    % Use a cell array first, then convert to 'categorical' for display 
    rel_diff_cell = cell(3, 1);
    for i = 1:3
        rel_diff_cell{i} = sprintf('%.2f%%', Rel_Diff_Raw(i));
    end
    Relative_Difference_Pct = categorical(rel_diff_cell);
    
    % Define the row names.
    row_names = {'NPV Risk Free', 'CVA', 'Risky NPV'};
    
    % Build final table
    comparison_table = table(Values_Constant_Sigma, Values_Piecewise_Constant, ...
                             Absolute_Difference, Relative_Difference_Pct, ...
                             'RowNames', row_names);
end