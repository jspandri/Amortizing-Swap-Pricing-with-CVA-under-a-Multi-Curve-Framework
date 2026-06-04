function [price, price_clean, CVA, details, tree] = price_swap_CVA_tree( ...
    a, sigma, K, settlement, scheduleSwap, stepsPerYear, ...
    RecoveryRate, HazardRate, discountCurve, pseudoCurve)
% PRICE_SWAP_CVA_TREE_GAMMA0
% Wrapper semplice per il pricing numerico tree-based nel caso
% MHW/HW con gamma = 0 e sigma costante.
%
% OUTPUT:
%   price       = NPV risky
%   price_clean = NPV risk-free
%   CVA         = credit valuation adjustment
%   details     = dettagli del pricing sul tree
%   tree        = struttura del tree calibrato

    maturityDate = scheduleSwap.payDates(end);

    % 1) setup tree
    tree = setup_mhw_tree( ...
        settlement, maturityDate, stepsPerYear, ...
        a, sigma, discountCurve, pseudoCurve, ...
        scheduleSwap.accrualStart, scheduleSwap.accrualEnd);
    
    % 2) fit OIS curve
    tree = fit_hw_tree_ois(settlement, tree);

    % 3) pricing risk-free + CVA
    [price_clean, ~, ~, CVA, price, details] = swap_npv_cva_tree( ...
        settlement, tree, scheduleSwap, K, HazardRate, RecoveryRate);
end