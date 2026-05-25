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
 [npvCorporate, npvFixedLeg, npvFloatLeg] = swap_riskfree_npv_vectorized(settlement, scheduleSwap, discountCurve,pseudoCurve );

%% Point 3--Amortizing Swap Pricing with CVA: simplified approach--
tenors = [1, 2, 3, 4, 5, 7, 10, 12, 15, 20, 25, 30];
expiries = [1/12, 3/12, 6/12, 9/12, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 15, 20, 25, 30]';
volMatrix_bps = [
    199.84, 212.56, 198.77, 184.19, 171.97, 159.20, 140.45, 137.54, 134.39, 129.24, 124.00, 119.97; % 1Mo
    178.40, 177.26, 172.48, 164.29, 156.13, 145.15, 129.74, 127.51, 124.93, 121.06, 116.76, 112.80; % 3Mo
    154.56, 156.09, 151.99, 145.75, 139.10, 130.17, 118.87, 117.41, 115.76, 112.80, 109.41, 106.18; % 6Mo
    143.08, 147.30, 141.40, 135.26, 130.06, 123.36, 113.64, 112.54, 111.24, 108.64, 106.58, 103.39; % 9Mo
    133.81, 137.43, 132.88, 126.90, 122.45, 116.57, 108.07, 107.36, 106.52, 104.35, 101.92,  99.56; % 1Yr
    121.09, 121.52, 116.67, 113.38, 109.72, 104.93,  98.82,  97.87,  96.48,  95.11,  92.55,  90.15; % 2Yr
    112.31, 111.59, 107.65, 104.33, 101.41,  97.49,  92.22,  91.17,  89.55,  88.15,  85.51,  82.83; % 3Yr
    105.23, 104.38, 101.77,  98.64,  95.86,  92.37,  87.97,  86.68,  84.66,  83.08,  80.28,  77.37; % 4Yr
     99.18,  97.92,  95.61,  93.21,  91.29,  88.44,  84.75,  83.34,  81.12,  79.62,  76.93,  74.13; % 5Yr
     94.13,  93.09,  90.57,  88.38,  86.65,  84.44,  81.35,  79.93,  77.70,  76.24,  73.66,  71.03; % 6Yr
     89.66,  88.76,  86.31,  84.39,  82.66,  80.75,  78.16,  76.79,  74.64,  73.09,  70.54,  68.11; % 7Yr
     86.31,  85.79,  83.72,  81.81,  80.34,  78.38,  75.72,  74.38,  72.30,  70.45,  68.08,  65.88; % 8Yr
     83.42,  83.31,  81.36,  79.84,  78.39,  76.47,  73.31,  72.01,  70.00,  68.03,  65.89,  63.86; % 9Yr
     81.53,  81.33,  79.80,  78.15,  76.55,  74.61,  70.99,  69.74,  67.82,  65.87,  63.81,  61.97; % 10Yr
     78.34,  78.18,  76.63,  75.80,  74.40,  72.11,  68.41,  67.04,  64.95,  62.76,  60.93,  59.14; % 12Yr
     76.42,  76.01,  74.37,  72.86,  71.15,  68.79,  64.86,  63.27,  60.84,  58.56,  56.80,  55.01; % 15Yr
     72.01,  71.79,  70.27,  68.67,  67.12,  64.69,  60.68,  59.03,  56.54,  53.83,  51.88,  49.85; % 20Yr
     69.86,  69.64,  67.95,  66.26,  64.49,  61.51,  57.25,  55.49,  52.84,  49.74,  47.37,  45.16; % 25Yr
     67.41,  67.47,  65.86,  64.00,  62.10,  58.91,  54.33,  52.35,  49.37,  46.34,  43.88,  41.61  % 30Yr
];

volMatrix = volMatrix_bps / 10000;
volData.tenors = tenors;
volData.expiries = expiries;
volData.matrix = volMatrix;
K_strike    = 0.0221; 
hazardRate = 0.05;   
recoveryRate = 0.60; % Esempio: 60% Recovery (LGD = 40%)

[Total_CVA, EE_profile] = calculate_cva_bachelier(...
    settlement, scheduleSwap, discountCurve, pseudoCurve, volData, hazardRate, recoveryRate,K_strike);

figure;
plot(scheduleSwap.payDates, EE_profile, '-o', 'LineWidth', 1.5, 'MarkerFaceColor', 'b');
title('Expected Exposure (EE) Profile over Swap Lifetime');
xlabel('Future Payment Dates (t_i)');
ylabel('Expected Exposure (EUR)');
grid on;
NPV=npvCorporate-Total_CVA;

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
%a_param     = ;       % Mean reversion speed
%sigma_param = ;      % Volatility of the short rate

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

