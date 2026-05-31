function [res_300_const, res_500_const, res_300_pwc, res_500_pwc] = execute_project_point6(...
    a_param, sigma_const, sigma_pwc, sigma_times, K_strike, settlement, ...
    scheduleSwap, precision_levels, RecoveryRate, HazardRates, discountCurve, pseudoCurve)
% EXECUTE_PROJECT_POINT6 Runs the Hull-White pricing and convergence analysis.
%
% This function performs the pricing of an amortizing swap under a multi-curve 
% Hull-White model, considering Counterparty Credit Risk (CVA). It compares 
% a Constant Volatility calibration vs a Piecewise Constant Volatility calibration 
% across different discretization grid levels, for two CDS profiles.
%
% INPUTS:
%   a_param                    : [Scalar] Mean reversion speed.
%   sigma_const                : [Scalar] Constant volatility parameter.
%   sigma_pwc                  : [Vector] Piecewise constant volatilities.
%   sigma_times                : [Vector] Calibration time buckets in years.
%   K_strike                   : [Scalar] Swap strike rate.
%   settlement                 : [Scalar] Valuation date (datenum).
%   scheduleSwap               : [Struct] Swap schedule container with active periods:
%                                        - .accrualStart : Period start dates (datenum)
%                                        - .accrualEnd   : Period end dates (datenum)
%                                        - .payDates     : Coupon payment dates (datenum)
%                                        - .notionals    : Active outstanding amortizing notionals
%                                        - .yf_pay       : Year fractions for payment periods (ACT/360)
%                                        - .F_forward    : Forward Libor rates
%                                        - .B_ois        : discounts at payments dates
%   precision_levels           : [Vector] Tree steps per year.
%   RecoveryRate               : [Scalar] Recovery rate.
%   HazardRates                : [Vector] Hazard rates for 300 and 500 bps CDS.
%   discountCurve              : [Struct] OIS discount curve.
%   pseudoCurve                : [Struct] Euribor pseudo-discount curve.
%
% OUTPUTS:
%   res_300_const              : [Struct] Convergence results (300 bps, Constant Sigma) containing:
%                                  .Steps_Per_Year, .Total_Time_Steps, .Risk_free_Swap_Price, .CVA, 
%                                  .Risky_Swap_Price 
%   res_500_const              : [Struct] Convergence results (500 bps, Constant Sigma) containing:
%                                  .Steps_Per_Year, .Total_Time_Steps, .Risk_free_Swap_Price, .CVA, 
%                                  .Risky_Swap_Price 
%   res_300_pwc                : [Struct] Convergence results (300 bps, Piecewise Constant) containing:
%                                  .Steps_Per_Year, .Total_Time_Steps, .Risk_free_Swap_Price, .CVA, 
%                                  .Risky_Swap_Price 
%   res_500_pwc                : [Struct] Convergence results (500 bps, Piecewise Constant)containing:
%                                  .Steps_Per_Year, .Total_Time_Steps, .Risk_free_Swap_Price, .CVA, 
%                                  .Risky_Swap_Price 

    %% 1. PRICING FOR CDS 300 bps
    
    % Pricing using Constant Sigma
    res_300_const = run_hw_pricing_amortizing_swap_CVA(a_param, sigma_const, ...
        sigma_times, K_strike, settlement, scheduleSwap, precision_levels,...
        RecoveryRate, HazardRates(1), discountCurve, pseudoCurve);
        
    % Pricing using Piecewise Constant (PWC) Sigma
    res_300_pwc = run_hw_pricing_amortizing_swap_CVA(a_param, sigma_pwc, ...
        sigma_times, K_strike, settlement, scheduleSwap, precision_levels,  ...
        RecoveryRate, HazardRates(1), discountCurve, pseudoCurve);

    %% 2. PRICING FOR CDS 500 bps
    
    % Pricing using Constant Sigma
    res_500_const = run_hw_pricing_amortizing_swap_CVA(a_param, sigma_const,...
        sigma_times, K_strike, settlement, scheduleSwap, precision_levels, ...
        RecoveryRate, HazardRates(2), discountCurve, pseudoCurve);
        
    % Pricing using Piecewise Constant (PWC) Sigma
    res_500_pwc = run_hw_pricing_amortizing_swap_CVA(a_param, sigma_pwc, ...
        sigma_times, K_strike, settlement, scheduleSwap, precision_levels, ...
        RecoveryRate, HazardRates(2), discountCurve, pseudoCurve);

    %% 3. PRINT DISCRETIZATION CONVERGENCE TABLES
    
    % Convert the struct outputs into MATLAB tables for display
    table_CDS_300_const = struct2table(res_300_const);
    table_CDS_500_const = struct2table(res_500_const);
    table_CDS_300_pwc   = struct2table(res_300_pwc);
    table_CDS_500_pwc   = struct2table(res_500_pwc);

    % Print tables to the command window
    disp('--> Discretization Convergence Table: CDS 300 bps (Constant Sigma)');
    disp(table_CDS_300_const);
    disp('--> Discretization Convergence Table: CDS 500 bps (Constant Sigma)');
    disp(table_CDS_500_const);
    disp('--> Discretization Convergence Table: CDS 300 bps (Piecewise Constant Sigma)');
    disp(table_CDS_300_pwc);
    disp('--> Discretization Convergence Table: CDS 500 bps (Piecewise Constant Sigma)');
    disp(table_CDS_500_pwc);

    %% 4. GENERATE CONVERGENCE PLOTS
    
    fig300 = plot_hw_convergence(res_300_const, res_300_pwc, 300);
    fig500 = plot_hw_convergence(res_500_const, res_500_pwc, 500);

    %% 5. COMPUTE AND PRINT FINAL COMPARISON TABLES
    
    % Evaluate the discrepancies between volatility approaches at highest precision
    disp('--> Comparison Table for CDS 300 bps (Constant vs Piecewise Constant Sigma):');
    comparison_table_300 = display_comparison_table(res_300_const, res_300_pwc);
    disp(comparison_table_300);

    disp('--> Comparison Table for CDS 500 bps (Constant vs Piecewise Constant Sigma):');
    comparison_table_500 = display_comparison_table(res_500_const, res_500_pwc);
    disp(comparison_table_500);

end