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

%% Read data

% 2022 Data ---------------------------------------------------------------
trade_date_22 = datenum("24-Jun-2022");
settlement_22 = datewrkdy(trade_date_22, 3); % Find settlement date (+2BD, 
                                             % datewrkdy needs offset+1=3)

% Bootstrap data
[euriborSet_22, estrSet_22] = read_bootstrap_data("20220626_Curve.xlsx", settlement_22);
% Volatility matrix data
vol_data_22 = read_vol_matrix_data("20220626_vol_matrix.xlsx");
% Swap amortizing plan
scheduleSwap_22 = read_amortizing_plan('SwapAmortizingPlan_v1', 'SwapPlan');


% 2023 Data ---------------------------------------------------------------
trade_date_23 = datenum("31-Jan-2023");
settlement_23 = datewrkdy(trade_date_23, 3);

% Bootstrap data
[euriborSet_23, estrSet_23] = read_bootstrap_data("20230131_Curve.xlsx", settlement_23);
% Volatility matrix data
vol_data_23 = read_vol_matrix_data("20230131_vol_matrix.xlsx");

%% 1) Multi-Curve Bootstrap

[discountCurve_22, pseudoCurve_22] = multi_curve_bootstrap(euriborSet_22, estrSet_22);

%% Point 2-- Risk Free Amortizing Swap Pricing--
K_strike    = 0.0221; 
swapMarketData = precompute_swap_market_data(settlement_22, scheduleSwap_22, discountCurve_22, pseudoCurve_22);
[NPV_riskfree, PV_fixed, PV_float] = swap_riskfree_npv(scheduleSwap_22, swapMarketData, K_strike);

%% Point 3--Amortizing Swap Pricing with CVA: simplified approach--

RecoveryRate               = 0.4;
CDS_spreads                = [300; 500] * 1e-4; % 300 bps and 500 bps
HazardRates                = CDS_spreads / (1 - RecoveryRate);
NPV = zeros(1,2);
EE_profile = zeros(length(scheduleSwap_22.payDates),2) ;
Total_CVA = zeros(1,2);

for i= 1:2
    [Total_CVA(i), EE_profile(:, i)] = calculate_cva_bachelier(...
        settlement_22, scheduleSwap_22, swapMarketData, vol_data_22, HazardRates(i), RecoveryRate,K_strike,discountCurve_22);
    NPV(i) = NPV_riskfree-Total_CVA(i);
end
plot_expected_exposures(scheduleSwap_22.payDates, EE_profile(:,1), EE_profile(:,2), CDS_spreads);

%% Point 4 -- Unwinding

maturity_date_not_adjusted = datenum("28-Jun-2037");
notional_amortized = scheduleSwap_22.notionals; 

% Define the known historical fixing rate for the ongoing period (2.202%)
past_fixing_rate = 0.02202;

% Bootstrap the OIS discount curve and Euribor pseudo-discount curve at the unwinding date
[discountCurve_23, pseudoCurve_23] = multi_curve_bootstrap(euriborSet_23, estrSet_23); 

% Generate the swap schedule starting from the new settlement date
scheduleSwap_23 = generate_swap_schedule(settlement_23, settlement_22, ...
    maturity_date_not_adjusted, notional_amortized);

% Compute the Risk-Free Net Present Value (NPV) of the swap at the unwinding date
NPV_RF = swap_riskfree_npv_v2(settlement_23, scheduleSwap_23, K_strike, ...
    discountCurve_23, pseudoCurve_23, past_fixing_rate);

% Compute CVA and Expected Exposure profile for the 300 bps CDS spread at unwinding
[CVA_300, EE_300] = calculate_cva_bachelier_v2(settlement_23, scheduleSwap_23, K_strike, ...
    discountCurve_23, pseudoCurve_23, vol_data_23, HazardRates(1), RecoveryRate, past_fixing_rate);

% Compute CVA and Expected Exposure profile for the 500 bps CDS spread at unwinding
[CVA_500, EE_500] = calculate_cva_bachelier_v2(settlement_23, scheduleSwap_23, K_strike, ...
    discountCurve_23, pseudoCurve_23, vol_data_23, HazardRates(2), RecoveryRate, past_fixing_rate);

% Plot the Expected Exposure profiles for the unwinding date
plot_expected_exposures(scheduleSwap_23.payDates, EE_300, EE_500, CDS_spreads);

% Compute the final unwinding NPV adjusted for Counterparty Credit Risk (CVA)
NPV_with_CVA_300 = NPV_RF - CVA_300;
NPV_with_CVA_500 = NPV_RF - CVA_500;

%% 5) Multi-Curve Swaption Model

% Define diagonals and gamma values
diag_expiries = [1; 3; 5; 8; 10; 12; 15]; 
diag_tenors = [15; 12; 10; 7; 5; 3; 1];
gammas = [0; 0.5; 1];

% Calibrate MHW parameters (with constant parameters and piecewise constant gamma) 
[results_const, results_pwc, mkt_prices] = calibrate_multicurve_swaption_model(settlement_22, discountCurve_22, pseudoCurve_22, vol_data_22, diag_expiries, diag_tenors, gammas);

%% Point 6: Hull-White Tree Pricing, Convergence, and Error Analysis

% Calibrated Hull-White parameters (from Point 5)
a_param     = results_const(1).a;       % Mean reversion speed
sigma_param = results_const(1).sigma;      % Volatility of the short rate

% Discretization levels (Time steps per year)
precision_levels = [1, 4, 12, 52, 365]; 

% Pricing (CDS 300 bps)
result_CDS_300 = run_hw_pricing_amortizing_swap_CVA(a_param, sigma_param, K_strike, ...
    settlement_22, maturity_date_not_adjusted, precision_levels, notional_amortized, ...
    RecoveryRate, HazardRates(1), discountCurve_22, pseudoCurve_22);

% Pricing (CDS 500 bps)
result_CDS_500 = run_hw_pricing_amortizing_swap_CVA(a_param, sigma_param, K_strike, ...
    settlement_22, maturity_date_not_adjusted, precision_levels, notional_amortized, ...
    RecoveryRate, HazardRates(2), discountCurve_22, pseudoCurve_22);

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


