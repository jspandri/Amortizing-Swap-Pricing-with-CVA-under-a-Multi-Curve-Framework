function out = node_forward_factors(settlement, tree, scheduleSwap)
% NODE_FORWARD_FACTORS_GAMMA0
% Calcola, per ogni periodo floating, i forward discount OIS al reset node,
% i pseudo-discount e i forward Libor nel caso gamma = 0.
%
% IMPORTANTE:
%   Qui NON assumiamo piu' che uno step del tree coincida con un trimestre.
%   Il tree e' su griglia uniforme; i periodi coupon sono mappati via scheduleMap.


    startDates = scheduleSwap.accrualStart(:);
    endDates   = scheduleSwap.accrualEnd(:);

    delta = scheduleSwap.yf_pay;
    delta = delta(:);

    nCoupons = length(startDates);

    if length(endDates) ~= nCoupons || length(delta) ~= nCoupons
        error('Schedule incoerente: startDates/endDates/delta.');
    end

    % mapping coupon dates -> grid
    if isfield(tree, 'scheduleMap') && ...
       isfield(tree.scheduleMap, 'floatStartIdx') && ...
       length(tree.scheduleMap.floatStartIdx) == nCoupons

        startIdx = tree.scheduleMap.floatStartIdx(:);
        endIdx   = tree.scheduleMap.floatEndIdx(:);
    else
        startTimes = yearfrac(settlement, startDates, 3);
        endTimes   = yearfrac(settlement, endDates, 3);

        startIdx = zeros(nCoupons,1);
        endIdx   = zeros(nCoupons,1);

        for k = 1:nCoupons
            [~, startIdx(k)] = min(abs(tree.timeGrid - startTimes(k)));
            [~, endIdx(k)]   = min(abs(tree.timeGrid - endTimes(k)));
        end
    end

    % curve iniziali
    discCurve   = tree.discountCurve;
    pseudoCurve = tree.pseudoCurve;

    P0d_start = get_discount_factor_by_zero_rates_linear_interp( ...
        settlement, startDates, ...
        discCurve.dates, discCurve.discounts);
    P0d_end = get_discount_factor_by_zero_rates_linear_interp( ...
        settlement, endDates, ...
        discCurve.dates, discCurve.discounts);

    P0p_start = get_discount_factor_by_zero_rates_linear_interp( ...
        settlement, startDates, ...
        pseudoCurve.dates, pseudoCurve.discounts);
    P0p_end = get_discount_factor_by_zero_rates_linear_interp( ...
        settlement, endDates, ...
        pseudoCurve.dates, pseudoCurve.discounts);

    P0d_start = P0d_start(:);
    P0d_end   = P0d_end(:);
    P0p_start = P0p_start(:);
    P0p_end   = P0p_end(:);

    B0      = P0d_end ./ P0d_start;
    Btilde0 = P0p_end ./ P0p_start;
    beta0   = B0 ./ Btilde0;

    if any(beta0 <= 0)
        error('beta0 non positivo: controlla le curve.');
    end

    nNodes = length(tree.x);
    nodeB      = zeros(nNodes, nCoupons);
    nodeBtilde = zeros(nNodes, nCoupons);
    nodeL      = zeros(nNodes, nCoupons);

    % ZCB nodo-per-nodo tra startIdx(i) ed endIdx(i)
    for k = 1:nCoupons
        nodeB(:,k) = zcb_nodes_between_grid_steps(tree, startIdx(k), endIdx(k));

        nodeBtilde(:,k) = nodeB(:,k) / beta0(k);
        nodeL(:,k)      = (1 ./ nodeBtilde(:,k) - 1) / delta(k);
    end

    out.startDates = startDates;
    out.endDates   = endDates;
    out.delta      = delta;

    out.startIdx   = startIdx;
    out.endIdx     = endIdx;

    out.market.P0d_start = P0d_start;
    out.market.P0d_end   = P0d_end;
    out.market.P0p_start = P0p_start;
    out.market.P0p_end   = P0p_end;

    out.market.B0        = B0;
    out.market.Btilde0   = Btilde0;
    out.market.beta0     = beta0;

    out.node.B           = nodeB;
    out.node.Btilde      = nodeBtilde;
    out.node.L           = nodeL;
end



function V = zcb_nodes_between_grid_steps(tree, startIdx, endIdx)

    if endIdx <= startIdx
        error('endIdx deve essere > startIdx.');
    end

    nNodes = length(tree.x);

    V = ones(nNodes,1); 

    pu = tree.fit.probUp;
    pm = tree.fit.probMid;
    pd = tree.fit.probDn;

    up  = tree.fit.destUp;
    mid = tree.fit.destMid;
    dn  = tree.fit.destDn;

    for i = endIdx-1:-1:startIdx
        cont = pu .* V(up) + pm .* V(mid) + pd .* V(dn);
        V    = tree.fit.nodeDF(:,i) .* cont;
    end
end