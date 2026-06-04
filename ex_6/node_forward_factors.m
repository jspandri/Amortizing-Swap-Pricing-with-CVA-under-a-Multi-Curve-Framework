function out = node_forward_factors(settlement, tree, scheduleSwap)
% NODE_FORWARD_FACTORS Computes forward OIS discount factors, pseudo-discounts
% and forward Euribor rates.
%
% INPUTS:
%   settlement   : [Scalar] Settlement date.
%   tree         : [Struct] Tree data structure containing grid arrays, model parameters, 
%                          discrete branching thresholds, calendar mappings, and deterministic spreads.
%   scheduleSwap : [Struct] Swap schedule container with active periods:
%                            - .accrualStart : Period start dates (datenum)
%                            - .accrualEnd   : Period end dates (datenum)
%                            - .payDates     : Coupon payment dates (datenum)
%                            - .notionals    : Active outstanding amortizing notionals
%                            - .yf_pay       : Year fractions for payment periods (ACT/360)
%                            - .F_forward    : Forward Libor rates
%                            - .B_ois        : discounts at payments dates%   
%
% OUTPUTS:
%   out          : [Struct] Containing forward discount factors (B), 
%                  pseudo-discounts, and forward rates (L) at each node.

        % Extract useful data
        startDates = scheduleSwap.accrualStart(:); % Force column vector for start dates
        endDates   = scheduleSwap.accrualEnd(:);   % Force column vector for end dates
        delta      = scheduleSwap.yf_pay;          % Extract year fractions
        delta      = delta(:);                     % Force column vector
        nCoupons   = length(startDates);           % Get number of coupon periods
        discCurve   = tree.discountCurve;          % Retrieve OIS curve
        pseudoCurve = tree.pseudoCurve;            % Retrieve Pseudo-discount curve
        
        % Check that schedule arrays have consistent lengths
        if length(endDates) ~= nCoupons || length(delta) ~= nCoupons
            error('Schedule inconsistent: startDates/endDates/delta.');
        end
        
        % Date Mapping
        % If pre-calculated scheduleMap exists, use it; otherwise, map dates to tree grid indices
        if isfield(tree, 'scheduleMap') && ...
           isfield(tree.scheduleMap, 'floatStartIdx') && ...
           length(tree.scheduleMap.floatStartIdx) == nCoupons
            startIdx = tree.scheduleMap.floatStartIdx(:);
            endIdx   = tree.scheduleMap.floatEndIdx(:);
        else
            % Calculate indices by finding the closest point in the timeGrid to the coupon dates
            startTimes = yearfrac(settlement, startDates, 3); % (ACT/365)
            endTimes   = yearfrac(settlement, endDates, 3);% (ACT/365)
            startIdx = zeros(nCoupons,1);
            endIdx   = zeros(nCoupons,1);
            for k = 1:nCoupons
                [~, startIdx(k)] = min(abs(tree.timeGrid - startTimes(k)));
                [~, endIdx(k)]   = min(abs(tree.timeGrid - endTimes(k)));
            end
        end
        
        
        % Interpolate discount factors at start and end dates for both curves
        P0d_start = get_discount_factor_by_zero_rates_linear_interp(...
            settlement, startDates,discCurve.dates, discCurve.discounts);
        P0d_end = get_discount_factor_by_zero_rates_linear_interp(...
            settlement, endDates, discCurve.dates, discCurve.discounts);

        P0p_start = get_discount_factor_by_zero_rates_linear_interp(...
            settlement, startDates,pseudoCurve.dates, pseudoCurve.discounts);
        P0p_end   = get_discount_factor_by_zero_rates_linear_interp(...
            settlement, endDates, pseudoCurve.dates, pseudoCurve.discounts);
        
        % Compute forward discounts, pseudo-discounts and beta factors
        B0      = P0d_end ./ P0d_start;
        Btilde0 = P0p_end ./ P0p_start;
        beta0   = B0 ./ Btilde0;
        
        % Ensure beta0 is valid
        if any(beta0 <= 0), error('beta0 non-positive: check the curves.'); end
        
        % Backward Induction 
        nNodes = length(tree.x);
        nodeB      = zeros(nNodes, nCoupons);
        nodeBtilde = zeros(nNodes, nCoupons);
        nodeL      = zeros(nNodes, nCoupons);
       
        for k = 1:nCoupons
            % Call helper to run full backward induction for each coupon
            nodeB(:,k) = zcb_nodes_between_grid_steps(tree, startIdx(k), endIdx(k));
            % Recover pseudo-discount and forward rate using the beta0 factor
            nodeBtilde(:,k) = nodeB(:,k) / beta0(k);
            nodeL(:,k)      = (1 ./ nodeBtilde(:,k) - 1) / delta(k);
        end

        % Save results
        out.startDates = startDates;
        out.endDates = endDates;
        out.delta = delta;
        out.startIdx = startIdx;
        out.endIdx = endIdx;
        out.market.P0d_start = P0d_start;
        out.market.P0d_end = P0d_end;
        out.market.P0p_start = P0p_start;
        out.market.P0p_end = P0p_end;
        out.market.B0 = B0;
        out.market.Btilde0 = Btilde0;
        out.market.beta0 = beta0;
        out.node.B = nodeB;
        out.node.Btilde = nodeBtilde;
        out.node.L = nodeL;

end

% =============================================================================
% HELPER FUNCTION: BACKWARD INDUCTION
% =============================================================================

function V = zcb_nodes_between_grid_steps(tree, startIdx, endIdx)
    % Boundary check
    if endIdx <= startIdx, error('endIdx deve essere > startIdx.'); end
    
    nNodes = length(tree.x);
    V = ones(nNodes,1); % Initialize ZCB at maturity (payoff = 1)
    
    % Cache transition probabilities and destinations
    pu = tree.fit.probUp; pm = tree.fit.probMid; pd = tree.fit.probDn;
    up = tree.fit.destUp; mid = tree.fit.destMid; dn = tree.fit.destDn;
    
    % Backward induction: propagate values from endIdx down to startIdx
    for i = endIdx-1:-1:startIdx
        % Calculate expected value in the next step
        cont = pu .* V(up) + pm .* V(mid) + pd .* V(dn);
        % Discount back to current step
        V    = tree.fit.nodeDF(:,i) .* cont;
    end
end