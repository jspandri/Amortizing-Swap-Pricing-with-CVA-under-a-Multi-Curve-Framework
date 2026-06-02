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
%ammortizing_data_22= read_amortizing_plan('SwapAmortizingPlan_v1');
rawSchedule_Excel = read_amortizing_plan('SwapAmortizingPlan_v1');

% 2023 Data ---------------------------------------------------------------
trade_date_23 = datenum("31-Jan-2023");
settlement_23 = datewrkdy(trade_date_23, 3);

% Bootstrap data
[euriborSet_23, estrSet_23] = read_bootstrap_data("20230131_Curve.xlsx", settlement_23);
% Volatility matrix data
vol_data_23 = read_vol_matrix_data("20230131_vol_matrix.xlsx");

%% 1) Multi-Curve Bootstrap (both 2022 and 2023)

% Bootstrap discount (OIS ESTR) and pseudo-discount (Euribor3m) curves

% 2022
[discountCurve_22, pseudoCurve_22] = multi_curve_bootstrap(euriborSet_22, estrSet_22, true);

% 2023
[discountCurve_23, pseudoCurve_23] = multi_curve_bootstrap(euriborSet_23, estrSet_23, true); 

%% 2) Risk Free Amortizing Swap Pricing

K_strike = 0.0221; 
%scheduleSwap_22 = generate_swap_schedule_22(settlement_22, ammortizing_data_22, discountCurve_22, pseudoCurve_22);
scheduleSwap_22 = generate_active_swap_schedule2(settlement_22, rawSchedule_Excel, discountCurve_22, pseudoCurve_22);
[NPV_riskfree, PV_fixed, PV_float] = swap_riskfree_npv(settlement_22,scheduleSwap_22,K_strike);

%% 3) Amortizing Swap Pricing with CVA

RecoveryRate               = 0.6;
CDS_spreads                = [300; 500] * 1e-4; % 300 bps and 500 bps
HazardRates                = CDS_spreads / (1 - RecoveryRate);
NPV_22 = zeros(1,2);
EE_profile = zeros(length(scheduleSwap_22.payDates),2) ;
Total_CVA = zeros(1,2);

for i = 1:2  
    [Total_CVA(i), EE_profile(:, i)] = calculate_cva_bachelier(...
        settlement_22,scheduleSwap_22,K_strike,discountCurve_22,vol_data_22,HazardRates(i),RecoveryRate);        
 
    NPV_22(i) = NPV_riskfree - Total_CVA(i);
end
plot_expected_exposures(scheduleSwap_22.payDates, EE_profile(:,1), EE_profile(:,2), CDS_spreads);

%% 4) Unwinding
maturity_date_not_adjusted = datenum("28-Jun-2037");
notional_amortized = scheduleSwap_22.notionals;
% Define the known historical fixing rate for the ongoing period
past_fixing_rate = 0.02141;

% Generate the swap schedule starting from the new settlement date
%scheduleSwap_23 = generate_swap_schedule(settlement_23, settlement_22, ...
   % maturity_date_not_adjusted, notional_amortized, discountCurve_23, pseudoCurve_23);
scheduleSwap_23 = generate_active_swap_schedule2(settlement_23, rawSchedule_Excel, discountCurve_23, pseudoCurve_23);

% Compute the Risk-Free Net Present Value (NPV) at the unwinding date
NPV_RF_23 = swap_riskfree_npv(settlement_23, scheduleSwap_23, K_strike, past_fixing_rate);

% Preallocate arrays
NPV_23 = zeros(1, 2);
EE_profile_23 = zeros(length(scheduleSwap_23.payDates), 2);
Total_CVA_23 = zeros(1, 2);

% Compute CVA and NPV for both CDS spreads
for i = 1:2
    [Total_CVA_23(i), EE_profile_23(:, i)] = calculate_cva_bachelier(...
        settlement_23, scheduleSwap_23, K_strike, discountCurve_23, ...
        vol_data_23, HazardRates(i), RecoveryRate, past_fixing_rate);
        
    % Compute the final unwinding NPV adjusted for Counterparty Credit Risk (CVA)
    NPV_23(i) = NPV_RF_23 - Total_CVA_23(i);
end

% Plot the Expected Exposure profiles for the unwinding date
plot_expected_exposures(scheduleSwap_23.payDates, EE_profile_23(:,1), EE_profile_23(:,2), CDS_spreads);

%% 5) Multi-Curve Swaption Model

% Define diagonals and gamma values
diag_expiries = [1; 3; 5; 8; 10; 12; 15]; 
diag_tenors = [15; 12; 10; 7; 5; 3; 1];
gammas = [0; 0.5; 1];

% Calibrate MHW parameters (with constant parameters and piecewise constant gamma) 
[results_const, results_pwc, mkt_prices] = calibrate_multicurve_swaption_model(settlement_22, discountCurve_22, pseudoCurve_22, vol_data_22, diag_expiries, diag_tenors, gammas);

% Re-Bootstrap with convexity adjustment
[pseudoCurves_adj_22] = rebootstrap_convexity_adjustment(euriborSet_22, estrSet_22, pseudoCurve_22, gammas, results_const);

%% 6) Hull-White Tree Pricing

% Extract pseudo-discounting curve reboostrapped with MHW parameters at
% gamma = 0
pseudoCurve_adj_22 = pseudoCurves_adj_22(1).curve;

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
    scheduleSwap_22, precision_levels, RecoveryRate, HazardRates, ...
    discountCurve_22, pseudoCurve_adj_22);
