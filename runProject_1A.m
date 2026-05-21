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
scheduleSwap = read_amortizing_plan('SwapAmortizingPlan_v1', 'SwapPlan');
[discounts, pseudo] = multi_curve_bootstrap(euriborSet, estrSet)

zerorates = from_discount_factors_to_zero_rates(settlement, estrSet.dates, discounts)

%% Point 2-- Risk Free Amortizing Swap Pricing--
%euliborCurv= quindi le date del eulibor e della discount le mettiamo
% apposto prima di chiamare la funzione ? 
%estCurv=
 [npvCorporate, npvFixedLeg, npvFloatLeg] = swap_riskfree_npv_vectorized(settlement, scheduleSwap, estCurv, euliborCurv);

%% Point 3--Amortizing Swap Pricing with CVA: simplified approach--
