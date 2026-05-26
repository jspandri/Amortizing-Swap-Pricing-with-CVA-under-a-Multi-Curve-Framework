% runProject_1A
%
% Project 1A: CVA Multi-Curve
% Elisa Colombo, Stefano Marino, Jacopo Spandri
% AY2025-2026
%
% to run:
% > runProject_1A

clear all;
close all;
clc;

addpath("utilities\")
addpath("data\")
addpath("ex3\")
addpath("ex2\")
%% Settings
formatData = 'dd/mm/yyyy';
settlement = datenum("28-Jun-2022");

vol_data = read_vol_matrix_data("20220626_vol_matrix.xlsx", settlement);


%% Read data

[euriborSet, estrSet] = read_bootstrap_data("20220626_Curve.xlsx", settlement);

scheduleSwap = read_amortizing_plan('SwapAmortizingPlan_v1', 'SwapPlan');

vol_matrix = read_vol_matrix_data("20220626_vol_matrix.xlsx", settlement);


%% 1) Multi-Curve Bootstrap

[discountCurve, pseudoCurve] = multi_curve_bootstrap(euriborSet, estrSet);

%% Point 2-- Risk Free Amortizing Swap Pricing--
K_strike    = 0.0221; 
swapMarketData = precompute_swap_market_data(settlement, scheduleSwap, discountCurve, pseudoCurve);
[NPV_riskfree, PV_fixed, PV_float] = swap_riskfree_npv(scheduleSwap, swapMarketData, K_strike);

%% Point 3--Amortizing Swap Pricing with CVA: simplified approach--
hazardRate = 0.05;   
recoveryRate = 0.60; % Esempio: 60% Recovery (LGD = 40%)

[Total_CVA, EE_profile] = calculate_cva_bachelier(...
    settlement, scheduleSwap, swapMarketData, vol_matrix, hazardRate, recoveryRate,K_strike,discountCurve);

figure;
plot(scheduleSwap.payDates, EE_profile, '-o', 'LineWidth', 1.5, 'MarkerFaceColor', 'b');
title('Expected Exposure (EE) Profile over Swap Lifetime');
xlabel('Future Payment Dates (t_i)');
ylabel('Expected Exposure (EUR)');
grid on;
NPV=NPV_riskfree-Total_CVA;

%% Point 4 --Unwinding 



%% 5) Multi-Curve Swaption Model

diag_expiries = [1, 3, 5, 8, 10, 12, 15]; 
diag_tenors = [15, 12, 10, 7, 5, 3, 1];

calibrate_multicurve_swaption_model(settlement, discountCurve, pseudoCurve, vol_data, diag_expiries, diag_tenors);

%% Point 6: Hull-White Tree Pricing, Convergence, and Error Analysis

% Swap Parameters 
maturity_date_not_adjusted = datenum("28-Jun-2037");
notional_amortized         = scheduleSwap.notionals; 
RecoveryRate               = 0.04;
CDS_spreads                = [300; 500] * 1e-4; % 300 bps and 500 bps
HazardRates                = CDS_spreads / (1 - RecoveryRate);
K_strike    = 0.0221;       % Fixed strike rate of the underlying swap

% Calibrated Hull-White parameters (from Point 5)
a_param     = 0.02;       % Mean reversion speed
sigma_param = 1e-8;      % Volatility of the short rate

% Discretization levels (Time steps per year)
precision_levels = [1, 4, 12, 52, 365]; 

% Pricing (CDS 300 bps)
result_CDS_300 = run_hw_pricing_amortizing_swap_CVA(a_param, sigma_param, K_strike, ...
    settlement, maturity_date_not_adjusted, precision_levels, notional_amortized, ...
    RecoveryRate, HazardRates(1), discountCurve, pseudoCurve);

% Pricing (CDS 500 bps)
result_CDS_500 = run_hw_pricing_amortizing_swap_CVA(a_param, sigma_param, K_strike, ...
    settlement, maturity_date_not_adjusted, precision_levels, notional_amortized, ...
    RecoveryRate, HazardRates(2), discountCurve, pseudoCurve);

% Convert results into MATLAB tables and print
table_CDS_300 = struct2table(result_CDS_300);
table_CDS_500 = struct2table(result_CDS_500);
disp('--> Discretization Convergence Table: CDS 300 bps');
disp(table_CDS_300);
disp('--> Discretization Convergence Table: CDS 500 bps');
disp(table_CDS_500);

% Generate plots for visualizing convergence
fig300 = plot_hw_convergence(result_CDS_300, a_param, sigma_param, 300);
fig500 = plot_hw_convergence(result_CDS_500, a_param, sigma_param, 500);
% 
% % Error Analysis (Tree vs. Analytical)
% % Analytical results from point 2 and 3
% analytical_npv_RiskFree = NPV_riskfree;     % from point 2     
% analytical_cva_300 = Total_CVA(1);               % from point 3
% analytical_cva_500 = Total_CVA(2);               % from point 3
% 
% % Compute and print error tables
% disp('--> Error Metrics for CDS 300 bps:');
% error_table_300 = display_error_table(analytical_npv_RiskFree, analytical_cva_300, result_CDS_300);
% 
% disp('--> Error Metrics for CDS 500 bps:');
% error_table_500 = display_error_table(analytical_npv_RiskFree, analytical_cva_500, result_CDS_500);
% 


