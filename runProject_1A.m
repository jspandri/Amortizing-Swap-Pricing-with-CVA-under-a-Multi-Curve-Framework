% runProject_1A
%
% CVA Multi-Curve: Amortizing Swap
% Group 1A:
%   Elisa Colombo, Stefano Marino, Jacopo Spandri
% AY2025-2026
%
% to run:
% > runProject_1A

clear all;
close all;
clc;

addpath("data\")
addpath(genpath("utilities\"));

%% Read data

% Swap amortizing plan
rawSchedule_Excel = read_amortizing_plan('SwapAmortizingPlan_v1');

% 2022 Data ---------------------------------------------------------------
trade_date_22 = datenum("24-Jun-2022");
settlement_22 = datewrkdy(trade_date_22, 3); % Find settlement date (+2BD, 
                                             % datewrkdy needs offset+1=3)
% Bootstrap data
[euriborSet_22, estrSet_22] = read_bootstrap_data("20220626_Curve.xlsx", settlement_22);
% Volatility matrix data
vol_data_22 = read_vol_matrix_data("20220626_vol_matrix.xlsx");

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
fprintf('\n 2)  Risk Free Amortizing Swap Pricing \n');

% Set fixed rate
K_strike = 0.0221; 
% Generate dates and payments schedule
scheduleSwap_22 = generate_active_swap_schedule(settlement_22, rawSchedule_Excel, discountCurve_22, pseudoCurve_22);

% Compute risk-free NPV
[NPV_riskfree, PV_fixed, PV_float] = swap_riskfree_npv(settlement_22,scheduleSwap_22,K_strike);
% Compute fair fixed rate
BPV = PV_fixed / K_strike; 
K_fair = PV_float / BPV;

fprintf('\n PV Fixed Leg                      : %.4f EUR\n', PV_fixed);
fprintf(' PV Floating Leg                   : %.4f EUR\n', PV_float);
fprintf(' Risk-Free NPV (Bank perspective)  : %.4f EUR\n', NPV_riskfree);
fprintf('\n Fair fixed rate                   : %.4f\n', K_fair);

%% 3) Amortizing Swap Pricing with CVA
fprintf('\n 3) Amortizing Swap Pricing with CVA \n');

RecoveryRate               = 0.6;               % Recovery rate
CDS_spreads                = [300; 500] * 1e-4; % 300 bps and 500 bps
HazardRates                = CDS_spreads / (1 - RecoveryRate); % Constant hazard rates

% Preallocate arrays
NPV_22 = zeros(1,2);
EE_profile = zeros(length(scheduleSwap_22.payDates),2) ;
Total_CVA = zeros(1,2);
vol_data_interp=zeros(length(scheduleSwap_22.payDates),2);

% Compute CVA with Swaptions (via Bachelier) and Risky NPV for both CDS spreads
for i = 1:2  
    [Total_CVA(i), EE_profile(:, i),vol_data_interp(:,i)] = calculate_cva_bachelier(...
        settlement_22,scheduleSwap_22,K_strike,discountCurve_22,vol_data_22,HazardRates(i),RecoveryRate);

    NPV_22(i) = NPV_riskfree - Total_CVA(i);
end

% Plots
plot_cva_dashboard(scheduleSwap_22.payDates, EE_profile, HazardRates, RecoveryRate, settlement_22, [300, 500]);
plot_interpolated_volatility(scheduleSwap_22.payDates, vol_data_interp(:, 1));

fprintf('\n CDS Spread = 300 bps\n');
fprintf('----------------------------------------------------\n');
fprintf(' Credit Value Adjustment (CVA)     : %.2f EUR\n', Total_CVA(1));
fprintf(' Risky NPV                         : %.2f EUR\n\n', NPV_22(1));
fprintf(' CDS Spread = 500 bps\n');
fprintf('----------------------------------------------------\n');
fprintf(' Credit Value Adjustment (CVA)     : %.2f EUR\n', Total_CVA(2));
fprintf(' Risky NPV                         : %.2f EUR\n', NPV_22(2));

%% 4) Unwinding
fprintf('\n 4) Swap Unwinding \n');

% Define the known historical fixing rate for the ongoing period
past_fixing_rate = 0.02141; 

% Generate the swap schedule starting from the new settlement date
scheduleSwap_23 = generate_active_swap_schedule(settlement_23, rawSchedule_Excel, discountCurve_23, pseudoCurve_23);

% Compute the Risk-Free Net Present Value (NPV) at the unwinding date
NPV_RF_23 = swap_riskfree_npv(settlement_23, scheduleSwap_23, K_strike, past_fixing_rate);

% Preallocate arrays
NPV_23 = zeros(1, 2);
EE_profile_23 = zeros(length(scheduleSwap_23.payDates), 2);
Total_CVA_23 = zeros(1, 2);

% Compute CVA and Risky NPV for both CDS spreads
for i = 1:2
    [Total_CVA_23(i), EE_profile_23(:, i)] = calculate_cva_bachelier(...
        settlement_23, scheduleSwap_23, K_strike, discountCurve_23, ...
        vol_data_23, HazardRates(i), RecoveryRate, past_fixing_rate);
       
     NPV_23(i) = NPV_RF_23 - Total_CVA_23(i);
end

% Plots
plot_cva_dashboard(scheduleSwap_23.payDates, EE_profile_23, HazardRates, RecoveryRate, settlement_23, [300, 500]);

fprintf('\n Risk-Free NPV (Bank perspective)  : %.2f EUR\n', NPV_RF_23);
fprintf('\n CDS Spread = 300 bps\n');
fprintf('----------------------------------------------------\n');
fprintf(' Credit Value Adjustment (CVA)     : %.2f EUR\n', Total_CVA_23(1));
fprintf(' Risky NPV                         : %.2f EUR\n\n', NPV_23(1));
fprintf(' CDS Spread = 500 bps\n');
fprintf('----------------------------------------------------\n');
fprintf(' Credit Value Adjustment (CVA)     : %.2f EUR\n', Total_CVA_23(2));
fprintf(' Risky NPV                         : %.2f EUR\n', NPV_23(2));

%% 5) Multi-Curve Swaption Model
fprintf('\n 5) Multi-Curve Swaption Model \n');

% Define diagonals and gamma values
diag_expiries = [1; 3; 5; 8; 10; 12; 15]; 
diag_tenors = [15; 12; 10; 7; 5; 3; 1];
gammas = [0; 0.5; 1];

% Calibrate MHW parameters (with constant parameters and piecewise constant sigma) 
[results_const, results_pwc, mkt_prices] = calibrate_multicurve_swaption_model(settlement_22, discountCurve_22, pseudoCurve_22, vol_data_22, diag_expiries, diag_tenors, gammas);

% Re-Bootstrap with convexity adjustment
[pseudoCurves_adj_22] = rebootstrap_convexity_adjustment(euriborSet_22, estrSet_22, pseudoCurve_22, gammas, results_const);

%% 6) Hull-White Tree Pricing and CVA Convergence Analysis
fprintf('\n 6) Hull-White Tree Pricing \n\n');

% Retrieve the pseudo-discounting curve re-bootstrapped with MHW parameters (gamma = 0)
pseudoCurve_adj_22 = pseudoCurves_adj_22(1).curve;

% Calibrated Hull-White parameters (from Point 5)
a_param     = results_const(1).a;      % Mean reversion speed (alpha)
sigma_const = results_const(1).sigma;  % Constant volatility (sigma)

% Define discretization levels (Time steps per year) for convergence analysis
precision_levels = [4, 12, 52, 365]; 

% Pricing for both CDS spreads for all time steps per year
res_tree = run_hw_pricing_amortizing_swap_CVA(a_param, sigma_const, K_strike, ...
    settlement_22, scheduleSwap_22, precision_levels, RecoveryRate, HazardRates, ...
    discountCurve_22, pseudoCurve_adj_22);

% Generate convergence plots
plot_hw_convergence(res_tree.hazard, [300, 500]);