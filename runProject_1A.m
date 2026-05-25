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

%% Settings
formatData = 'dd/mm/yyyy';
settlement = datenum("28-Jun-2022");

%% Read data

[euriborSet, estrSet] = read_Excel_data("20220626_Curve.xlsx", settlement);
scheduleSwap = read_amortizing_plan('SwapAmortizingPlan_v1', 'SwapPlan');


%% 1) Multi-Curve Bootstrap

[discountCurve, pseudoCurve] = multi_curve_bootstrap(euriborSet, estrSet);

%%

zerorates = from_discount_factors_to_zero_rates(settlement, estrSet.dates, discounts)

%% Point 2-- Risk Free Amortizing Swap Pricing--
%euliborCurv= quindi le date del eulibor e della discount le mettiamo
% apposto prima di chiamare la funzione ? 
%estCurv=
 [npvCorporate, npvFixedLeg, npvFloatLeg] = swap_riskfree_npv_vectorized(settlement, scheduleSwap, estCurv, euliborCurv);

%% Point 3--Amortizing Swap Pricing with CVA: simplified approach--


%% Point 6: Hull-White Tree Pricing, Convergence, and Error Analysis

% Swap Parameters 
maturity_date_not_adjusted = datenum("28-Jun-2037");
notional_amortized         = scheduleSwap.notionals; 
RecoveryRate               = 0.04;
CDS_spreads                = [300; 500] * 1e-4; % 300 bps and 500 bps
HazardRates                = CDS_spreads / (1 - RecoveryRate);
K_strike    = 0.0221;       % Fixed strike rate of the underlying swap

% Calibrated Hull-White parameters (from Point 5)
a_param     = 0.01;       % Mean reversion speed
sigma_param = 0.08;      % Volatility of the short rate

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
% 
% % Analytical results from point 2 and 3
% analytical_npv_RiskFree = npvCorporate;     % from point 2     
% analytical_cva_300 = cva_300;               % from point 3
% analytical_cva_500 = cva_500;               % from point 3
% 
% % Compute and print error tables
% disp('--> Error Metrics for CDS 300 bps:');
% error_table_300 = display_error_table(npv_RiskFree, cva_300, resultCDS_300);
% 
% disp('--> Error Metrics for CDS 500 bps:');
% error_table_500 = display_error_table(npv_RiskFree, cva_500, struct_CDS_500);

