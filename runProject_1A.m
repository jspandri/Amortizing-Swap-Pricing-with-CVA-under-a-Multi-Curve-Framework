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

%%

[euriborSet, estrSet] = read_Excel_data("20220626_Curve.xlsx", settlement);

[discountCurve, pseudoCurve] = multi_curve_bootstrap(euriborSet, estrSet);

zerodisc = from_discount_factors_to_zero_rates(settlement, discountCurve.dates, discountCurve.discounts);
zeropseudo = from_discount_factors_to_zero_rates(settlement, pseudoCurve.dates, pseudoCurve.discounts);

figure;

eurDates  = datetime(pseudoCurve.dates, 'ConvertFrom', 'datenum');
estrDates = datetime(discountCurve.dates, 'ConvertFrom', 'datenum');

plot(eurDates, zeropseudo,  'LineWidth', 1.5);
hold on;

plot(estrDates, zerodisc, 'LineWidth', 1.5);

grid on;
zoom on;

xlabel('Date');
ylabel('Zero Rate');
title('EURIBOR vs ESTR Zero Rates');

legend('EURIBOR', 'ESTR', 'Location', 'best');

%%

scheduleSwap = read_amortizing_plan('SwapAmortizingPlan_v1', 'SwapPlan');
zerorates = from_discount_factors_to_zero_rates(settlement, estrSet.dates, discounts)

%% Point 2-- Risk Free Amortizing Swap Pricing--
%euliborCurv= quindi le date del eulibor e della discount le mettiamo
% apposto prima di chiamare la funzione ? 
%estCurv=
 [npvCorporate, npvFixedLeg, npvFloatLeg] = swap_riskfree_npv_vectorized(settlement, scheduleSwap, estCurv, euliborCurv);

%% Point 3--Amortizing Swap Pricing with CVA: simplified approach--
