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
addpath("ex_4\")

%% Settings

formatData = 'dd/mm/yyyy';
settlement = datenum("28-Jun-2022");

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

RecoveryRate               = 0.4;
CDS_spreads                = [300; 500] * 1e-4; % 300 bps and 500 bps
HazardRates                = CDS_spreads / (1 - RecoveryRate);
NPV = zeros(1,2);
EE_profile = zeros(length(scheduleSwap.payDates),2) ;
Total_CVA = zeros(1,2);

for i= 1:2
    [Total_CVA(i), EE_profile(:, i)] = calculate_cva_bachelier(...
        settlement, scheduleSwap, swapMarketData, vol_matrix, HazardRates(i), RecoveryRate,K_strike,discountCurve);
    NPV(i) = NPV_riskfree-Total_CVA(i);
end
plot_expected_exposures(scheduleSwap.payDates, EE_profile(:,1), EE_profile(:,2), CDS_spreads);

%% Point 4 -- Unwinding

trade_date = datenum("31-Jan-2023");
settlement31 = following_day_convention(trade_date, 2, 0, 0, 1, false);
maturity_date_not_adjusted = datenum("28-Jun-2037");
notional_amortized = scheduleSwap.notionals; 

% Read the Bachelier volatility matrix at the unwinding date
vol_matrix31 = read_vol_matrix_data("20230131_vol_matrix.xlsx", settlement31);

% Define the known historical fixing rate for the ongoing period (2.202%)
past_fixing_rate = 0.02202;

% Load mkt data and bootstrap the OIS discount curve and Euribor pseudo-discount curve at the unwinding date
[euriborSet31, estrSet31] = read_bootstrap_data("20230131_Curve.xlsx", settlement31);
[discountCurve31, pseudoCurve31] = multi_curve_bootstrap(euriborSet31, estrSet31); 

% Generate the swap schedule starting from the new settlement date
scheduleSwap31 = generate_swap_schedule(settlement31, settlement, ...
    maturity_date_not_adjusted, notional_amortized);

% Compute the Risk-Free Net Present Value (NPV) of the swap at the unwinding date
NPV_RF = swap_riskfree_npv_v2(settlement31, scheduleSwap31, K_strike, ...
    discountCurve31, pseudoCurve31, past_fixing_rate);

% Compute CVA and Expected Exposure profile for the 300 bps CDS spread at unwinding
[CVA_300, EE_300] = calculate_cva_bachelier_v2(settlement31, scheduleSwap31, K_strike, ...
    discountCurve31, pseudoCurve31, vol_matrix31, HazardRates(1), RecoveryRate, past_fixing_rate);

% Compute CVA and Expected Exposure profile for the 500 bps CDS spread at unwinding
[CVA_500, EE_500] = calculate_cva_bachelier_v2(settlement31, scheduleSwap31, K_strike, ...
    discountCurve31, pseudoCurve31, vol_matrix31, HazardRates(2), RecoveryRate, past_fixing_rate);

% Plot the Expected Exposure profiles for the unwinding date
plot_expected_exposures(scheduleSwap31.payDates, EE_300, EE_500, CDS_spreads);

% Compute the final unwinding NPV adjusted for Counterparty Credit Risk (CVA)
NPV_with_CVA_300 = NPV_RF - CVA_300;
NPV_with_CVA_500 = NPV_RF - CVA_500;

%% 5) Multi-Curve Swaption Model

diag_expiries = [1, 3, 5, 8, 10, 12, 15]; 
diag_tenors = [15, 12, 10, 7, 5, 3, 1];

calibrate_multicurve_swaption_model(settlement, discountCurve, pseudoCurve, vol_data, diag_expiries, diag_tenors);

%% Point 6: Hull-White Tree Pricing, Convergence, and Error Analysis

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


