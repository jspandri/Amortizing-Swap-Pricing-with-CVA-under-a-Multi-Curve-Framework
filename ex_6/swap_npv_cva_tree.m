function [NPV_rf, PV_float, PV_fixed, CVA, NPV_risky, details] = ...
    swap_npv_cva_tree(settlement, tree, scheduleSwap, K, HazardRate, RecoveryRate)
% SWAP_NPV_CVA_TREE
% Prezzo risk-free e risky di uno swap amortizing nel tree MHW/HW con gamma = 0.
%
% Punto di vista BANCA:
%   riceve floating Euribor 3M
%   paga fixed K
%
% CVA discretizzata su tutta la griglia del tree:
%   CVA = LGD * sum_i PD_i * E[D(0,t_i) * max(V_i,0)]
%
% dove V_i e' il valore residuo NETTO del contratto al layer i.


    % ------------------------------------------------------------
    % 1) Forward quantities multicurve nodo-per-nodo
    % ------------------------------------------------------------
    fwd = node_forward_factors(settlement, tree, scheduleSwap);

    notionals = scheduleSwap.notionals(:);
    nCoupons  = length(fwd.delta);

    if length(notionals) == nCoupons + 1
        notionals = notionals(1:end-1);
    elseif length(notionals) ~= nCoupons
        error('scheduleSwap.notionals deve avere lunghezza nCoupons o nCoupons+1.');
    end

    notionals = notionals(:);
    delta     = fwd.delta(:);

    nNodes = length(tree.x);
    nCols  = tree.nSteps + 1;

    % ------------------------------------------------------------
    % 2) Coupon values at reset times, embedded on full grid
    % ------------------------------------------------------------
    couponFloatAtReset = zeros(nNodes, nCols);
    couponFixedAtReset = zeros(nNodes, nCols);

    for k = 1:nCoupons
        idx = fwd.startIdx(k);

        % valore al reset time T_i del coupon pagato a T_{i+1}
        valFloat_k = notionals(k) * delta(k) * fwd.node.L(:,k) .* fwd.node.B(:,k);
        valFixed_k = notionals(k) * delta(k) * K              .* fwd.node.B(:,k);

        % se piu' coupon mappano sullo stesso layer, si sommano
        couponFloatAtReset(:, idx) = couponFloatAtReset(:, idx) + valFloat_k;
        couponFixedAtReset(:, idx) = couponFixedAtReset(:, idx) + valFixed_k;
    end

    couponNetAtReset = couponFloatAtReset - couponFixedAtReset;

    % ------------------------------------------------------------
    % 3) Backward induction on the FULL TREE
    % ------------------------------------------------------------
    V_float = backward_value_full_grid(tree, couponFloatAtReset);
    V_fixed = backward_value_full_grid(tree, couponFixedAtReset);
    V_net   = backward_value_full_grid(tree, couponNetAtReset);

    idx0 = tree.l_max + 1;

    PV_float = V_float(idx0, 1);
    PV_fixed = V_fixed(idx0, 1);
    NPV_rf   = V_net(idx0, 1);

    % ------------------------------------------------------------
    % 4) CVA on the whole tree
    % ------------------------------------------------------------
    LGD = 1 - RecoveryRate;

    statePrices = tree.fit.statePrices;   % discounted state prices q_{i,j}
    marketDF    = tree.fit.marketDF(:);   % P(0,t_i)

    discEE = zeros(tree.nSteps, 1);
    EE     = zeros(tree.nSteps, 1);
    PDstep = zeros(tree.nSteps, 1);
    CVA    = 0.0;

    for i = 1:tree.nSteps
        t_curr = tree.gridDates(i);
        t_next = tree.gridDates(i+1);

        y_curr = yearfrac(settlement, t_curr, 3);
        y_next = yearfrac(settlement, t_next, 3);

        % default probability over [t_i, t_{i+1}] under constant hazard
        PD_i = exp(-HazardRate * y_curr) - exp(-HazardRate * y_next);
        PDstep(i) = PD_i;

        % discounted expected exposure at t_i
        discEE_i = sum(statePrices(:, i) .* max(V_net(:, i), 0));
        discEE(i) = discEE_i;

        % undiscounted expected exposure at t_i (optional diagnostic)
        if marketDF(i) > 1e-16
            probs_i = statePrices(:, i) / marketDF(i);
            EE(i) = sum(probs_i .* max(V_net(:, i), 0));
        else
            EE(i) = 0.0;
        end

        CVA = CVA + LGD * PD_i * discEE_i;
    end

    NPV_risky = NPV_rf - CVA;

    % ------------------------------------------------------------
    % 5) Diagnostics
    % ------------------------------------------------------------
    details = struct();

    details.nCoupons     = nCoupons;
    details.notionals    = notionals;
    details.delta        = delta;

    details.forwardData  = fwd;

    details.couponFloatAtReset = couponFloatAtReset;
    details.couponFixedAtReset = couponFixedAtReset;
    details.couponNetAtReset   = couponNetAtReset;

    details.V_float = V_float;
    details.V_fixed = V_fixed;
    details.V_net   = V_net;

    details.PV_float = PV_float;
    details.PV_fixed = PV_fixed;
    details.NPV_rf   = NPV_rf;

    details.PDstep   = PDstep;
    details.discEE   = discEE;     % E[D(0,t_i) V_i^+]
    details.EE       = EE;         % E[V_i^+]
    details.CVA      = CVA;
    details.NPV_risky = NPV_risky;
end


function V = backward_value_full_grid(tree, cashflowsAtGridTime)
% BACKWARD_VALUE_FULL_GRID
% cashflowsAtGridTime(:,i) e' un valore al tempo t_i gia' espresso al layer i.
% La backward induction calcola il valore residuo in ogni nodo e layer.

    nNodes = length(tree.x);
    nSteps = tree.nSteps;

    if size(cashflowsAtGridTime,1) ~= nNodes || size(cashflowsAtGridTime,2) ~= nSteps+1
        error('Dimensioni di cashflowsAtGridTime non coerenti col tree.');
    end

    V = zeros(nNodes, nSteps + 1);

    pu  = tree.fit.probUp;
    pm  = tree.fit.probMid;
    pd  = tree.fit.probDn;

    up  = tree.fit.destUp;
    mid = tree.fit.destMid;
    dn  = tree.fit.destDn;

    nodeDF = tree.fit.nodeDF;

    for i = nSteps:-1:1
        cont = pu .* V(up, i+1) + pm .* V(mid, i+1) + pd .* V(dn, i+1);
        V(:, i) = cashflowsAtGridTime(:, i) + nodeDF(:, i) .* cont;
    end
end