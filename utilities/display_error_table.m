function err_table = display_error_table(analytical_rf, analytical_cva, tree_struct)
% DISPLAY_ERROR_TABLE Computes and print errors between analytical
% prices/CVA and model ones.
%
% INPUTS:
%   analytical_rf   : [Scalar] Risk-free swap price from Point 2
%   analytical_cva  : [Scalar] Simplified approach CVA from Point 3
%   tree_struct     : [Struct] Output structure from the Point 6 Tree execution
%
% OUTPUTS:
%   err_table       : [Table] MATLAB table displaying the errors

    % 1. Compute Analytical Risky Target
    analytical_risky = analytical_rf - analytical_cva;

    % 2. Extract Max-Precision Tree (last element in the arrays)
    tree_rf    = tree_struct.Risk_free_Swap_Price(end);
    tree_cva   = tree_struct.CVA(end);
    tree_risky = tree_struct.Risky_Swap_Price(end);

    % 3. Put data into arrays
    Metrics = {'Risk-Free NPV (Clean)'; 'CVA'; 'Risky NPV'};
    Analytical_Model = [analytical_rf; analytical_cva; analytical_risky];
    HW_Tree_Model    = [tree_rf; tree_cva; tree_risky];
    
    % 4. Compute Absolute Residual Errors
    Absolute_Error = abs(Analytical_Model - HW_Tree_Model);

    % 5. Build and print the structured table object
    err_table = table(Metrics, Analytical_Model, HW_Tree_Model, Absolute_Error, ...
        'VariableNames', {'Pricing_Metric', 'Analytical_Results', 'HW_Tree_Max_Steps', 'Absolute_Error'});
    
    disp(err_table);
end