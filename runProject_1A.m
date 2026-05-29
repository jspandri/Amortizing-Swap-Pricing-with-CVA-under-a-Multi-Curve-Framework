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
addpath("data\","ex2\","ex3\","ex_4\","ex_6\")

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
scheduleSwap_22 = read_amortizing_plan('SwapAmortizingPlan_v1');


% 2023 Data ---------------------------------------------------------------
trade_date_23 = datenum("31-Jan-2023");
settlement_23 = datewrkdy(trade_date_23, 3);

% Bootstrap data
[euriborSet_23, estrSet_23] = read_bootstrap_data("20230131_Curve.xlsx", settlement_23);
% Volatility matrix data
vol_data_23 = read_vol_matrix_data("20230131_vol_matrix.xlsx");

%% 1) Multi-Curve Bootstrap

% Bootstrap discount (OIS ESTR) and pseudo-discount (Euribor3m) curves
[discountCurve_22, pseudoCurve_22] = multi_curve_bootstrap(euriborSet_22, estrSet_22);

%% 2) Risk Free Amortizing Swap Pricing

K_strike = 0.0221; 
swapMarketData = precompute_swap_market_data(settlement_22, scheduleSwap_22, discountCurve_22, pseudoCurve_22);
[NPV_riskfree, PV_fixed, PV_float] = swap_riskfree_npv(scheduleSwap_22, swapMarketData, K_strike);

%% 3) Amortizing Swap Pricing with CVA

RecoveryRate               = 0.6;
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

%% 4) Unwinding

maturity_date_not_adjusted = datenum("28-Jun-2037");
notional_amortized = scheduleSwap_22.notionals;

% Define the known historical fixing rate for the ongoing period (2.202%)
past_fixing_rate = 0.02202;

% Bootstrap the OIS discount curve and Euribor pseudo-discount curve at the unwinding date
[discountCurve_23, pseudoCurve_23] = multi_curve_bootstrap(euriborSet_23, estrSet_23); 

% Generate the swap schedule starting from the new settlement date
scheduleSwap_23 = generate_swap_schedule(settlement_23, settlement_22, ...
    maturity_date_not_adjusted, notional_amortized,discountCurve_23,pseudoCurve_23);

% Compute the Risk-Free Net Present Value (NPV) of the swap at the unwinding date
NPV_RF = swap_riskfree_npv_v2(settlement_23, scheduleSwap_23, K_strike, past_fixing_rate);

% Compute CVA and Expected Exposure profile for the 300 bps CDS spread at unwinding
[CVA_300, EE_300] = calculate_cva_bachelier_v2(settlement_23, scheduleSwap_23, K_strike, ...
    discountCurve_23, vol_data_23, HazardRates(1), RecoveryRate, past_fixing_rate);

% Compute CVA and Expected Exposure profile for the 500 bps CDS spread at unwinding
[CVA_500, EE_500] = calculate_cva_bachelier_v2(settlement_23, scheduleSwap_23, K_strike, ...
    discountCurve_23, vol_data_23, HazardRates(2), RecoveryRate, past_fixing_rate);

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

%% 6) Hull-White Tree Pricing


% Calibrated Hull-White parameters (from Point 5)
a_param             = results_const(1).a;      % Mean reversion speed
sigma_const         = results_const(1).sigma;  % Scalar constant volatility
sigma_pwc           = results_pwc(1).sigmas;   % Piecewise Constant volatility
sigma_times         = diag_expiries;           % Calibration buckets in years

% Discretization levels (Time steps per year)
precision_levels = [1, 4, 12, 52, 365]; 

% Pricing of an amortizing swap under a multi-curve Hull-White model. We compare 
% a Constant Volatility calibration vs a Piecewise Constant Volatility calibration 
% across different discretization grid levels, for two CDS profiles.
[res_300_const, res_500_const, res_300_pwc, res_500_pwc] = execute_project_point6(...
    a_param, sigma_const, sigma_pwc, sigma_times, K_strike, settlement_22, ...
    maturity_date_not_adjusted, precision_levels, notional_amortized, ...
    RecoveryRate, HazardRates, discountCurve_22, pseudoCurve_22);