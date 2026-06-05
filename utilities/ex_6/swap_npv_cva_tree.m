function [NPV_rf, PV_float, PV_fixed, CVA, NPV_risky, details] = ...
    swap_npv_cva_tree(settlement, tree, scheduleSwap, K, HazardRates, RecoveryRate)
% SWAP_NPV_CVA_TREE Computes Risk-Free CVA and Risky NPV of an amortizing swap on a HW Tree.
%
% This function performs a backward induction on the full grid to evaluate 
% the continuous net present value of the swap. It then calculates the 
% Unilateral Credit Value Adjustment (CVA) over the entire continuous time grid.
%
% BANK'S PERSPECTIVE:
%   - Receives floating rate (Euribor 3M)
%   - Pays fixed rate (K)
%
% CVA FRAMEWORK:
%   CVA = LGD * sum_i [ PD(t_i, t_i+1) * E[ D(0,t_i) * max(V_i, 0) ] ]
%
% INPUTS:
%   settlement   : [Scalar] Settlement date t0 (datenum).
%   tree         : [Struct] Tree data structure containing grid arrays, model parameters, 
%                        discrete branching thresholds, calendar mappings, and deterministic spreads.
%   scheduleSwap : [Struct] Swap schedule container with active periods:
%                            - .accrualStart : Period start dates (datenum)
%                            - .accrualEnd   : Period end dates (datenum)
%                            - .payDates     : Coupon payment dates (datenum)
%                            - .notionals    : Active outstanding amortizing notionals
%                            - .yf_pay       : Year fractions for payment periods (ACT/360)
%                            - .F_forward    : Forward Libor rates
%                            - .B_ois        : discounts at payments datesù
%   K            : [Scalar] Fixed strike rate.
%   HazardRates  : [Vector] Constant default intensities (lambda).
%   RecoveryRate : [Scalar] Recovery rate (R).
%
% OUTPUTS:
%   NPV_rf       : [Scalar] Risk-Free Net Present Value.
%   PV_float     : [Scalar] Present Value of the Floating Leg.
%   PV_fixed     : [Scalar] Present Value of the Fixed Leg.
%   CVA          : [Vector] Credit Valuation Adjustment.
%   NPV_risky    : [Vector] Risky Swap NPV (NPV_rf - CVA).
%   details      : [Struct] Prices, CVA and exposure profiles.

    % 1. MULTI-CURVE FORWARD QUANTITIES

    % Extract pre-computed forward rates and discounts for the schedule
    fwd = node_forward_factors(settlement, tree, scheduleSwap);
    
    notionals = scheduleSwap.notionals(:);
    delta     = fwd.delta(:);
    nCoupons  = length(delta);

    % Handle potential schedule mapping mismatches safely
    if length(notionals) == nCoupons + 1
        notionals = notionals(1:end-1);
    elseif length(notionals) ~= nCoupons
        error('scheduleSwap.notionals must have length nCoupons or nCoupons+1.');
    end
    notionals = notionals(:);

    nNodes = length(tree.x);
    nCols  = tree.nSteps + 1;

    % 2. CASH FLOW GENERATION

    % Pre-allocate the grid matrices mapping cash flows to specific reset times
    couponFloatAtReset = zeros(nNodes, nCols);
    couponFixedAtReset = zeros(nNodes, nCols);

    % Compute all coupon values across all nodes simultaneously
    % Weights: [1 x nCoupons] vector of Notional * YearFraction
    weights = (notionals .* delta)'; 
    
    % valFloat_matrix / valFixed_matrix: [nNodes x nCoupons] matrices 
    valFloat_matrix = fwd.node.L .* fwd.node.B .* weights;
    valFixed_matrix = fwd.node.B .* (weights * K);

    % Map the generated matrices onto the tree grid timelines
    for k = 1:nCoupons
        idx = fwd.startIdx(k);
        % If multiple coupons map to the same node layer, they are accumulated (+)
        couponFloatAtReset(:, idx) = couponFloatAtReset(:, idx) + valFloat_matrix(:, k);
        couponFixedAtReset(:, idx) = couponFixedAtReset(:, idx) + valFixed_matrix(:, k);
    end

    % Define the net cash flow injection matrix (Bank receives float, pays fixed)
    couponNetAtReset = couponFloatAtReset - couponFixedAtReset;

    % 3. BACKWARD INDUCTION ON THE FULL GRID

    % Rollback the future expected values iteratively from maturity to t0
    V_net   = backward_value_full_grid(tree, couponNetAtReset);

    % Retrive NPV floating/fixed leg by using the states prices
    statePrices = tree.fit.statePrices;  
    PV_float = sum(sum(statePrices .* couponFloatAtReset));
    PV_fixed = sum(sum(statePrices .* couponFixedAtReset));
    NPV_rf   = PV_float - PV_fixed;

    % 4. CVA COMPUTATION (vectorized to work with a vector of hazard rates)
    LGD = 1 - RecoveryRate;
    statePrices = tree.fit.statePrices;   % Discounted prices
    marketDF    = tree.fit.marketDF(:);   % Market OIS discounts P(0, t_i)

    % Generate year fractions for the entire time grid simultaneously (ACT/365)
    y_grid = yearfrac(settlement, tree.gridDates, 3);
    
    % Extract the positive exposure profile strictly up to nSteps 
    % (We exclude nSteps+1 because maturity implies contract expiration)
    V_net_positive = max(V_net(:, 1:tree.nSteps), 0);

    % Compute Discounted Expected Exposure (discEE): E[ D(0,t_i) * max(V_i, 0) ]
    % Sum over rows (dimension 1) to compress spatial nodes into a time vector
    discEE = sum(statePrices(:, 1:tree.nSteps) .* V_net_positive, 1)';

    % Undiscounted Expected Exposure (EE): E[ max(V_i, 0) ]
    % Guard against division by zero for extremely small discount factors
    safe_marketDF = max(marketDF(1:tree.nSteps), 1e-16);
    EE = discEE ./ safe_marketDF;

    HazardRates = HazardRates(:).';
    t0_vec      = y_grid(1:end-1);          
    t1_vec      = y_grid(2:end);           
    
    % Calculate marginal Default Probabilities for all steps: [nSteps x 1]
    PDstep = exp(-t0_vec * HazardRates) - exp(-t1_vec * HazardRates);
    % CVA Calculation
    CVA       = LGD * sum(PDstep .* discEE, 1).';  
    % Final Risky Swap Pricing
    NPV_risky = NPV_rf - CVA;                          

    % 5. SAVE RESULTS

    details = struct();
    details.nCoupons           = nCoupons;
    details.notionals          = notionals;
    details.delta              = delta;
    details.forwardData        = fwd;
    details.couponFloatAtReset = couponFloatAtReset;
    details.couponFixedAtReset = couponFixedAtReset;
    details.couponNetAtReset   = couponNetAtReset;
    details.V_net              = V_net;
    details.PV_float           = PV_float;
    details.PV_fixed           = PV_fixed;
    details.NPV_rf             = NPV_rf;
    
    % Store CVA diagnostic profiles
    details.HazardRates        = HazardRates;
    details.PDstep             = PDstep;
    details.discEE             = discEE; % Discounted Expected Exposure
    details.EE                 = EE;     % Undiscounted Expected Exposure
    details.CVA                = CVA;
    details.NPV_risky          = NPV_risky;
end

% =============================================================================
% HELPER FUNCTION: BACKWARD INDUCTION
% =============================================================================
function V = backward_value_full_grid(tree, cashflowsAtGridTime)
% BACKWARD_VALUE_FULL_GRID Propagates future cash flows backwards through the lattice.
%
% INPUTS:
%   tree                : [Struct] Tree data structure containing grid arrays, model parameters, 
%                                   discrete branching thresholds, calendar mappings, and deterministic spreads.
%   cashflowsAtGridTime : [Matrix, nNodes x nSteps+1] Local cash flows to inject.
%
% OUTPUTS:
%   V                   : [Matrix, nNodes x nSteps+1] Residual value array.

    nNodes = length(tree.x);
    nSteps = tree.nSteps;

    if size(cashflowsAtGridTime, 1) ~= nNodes || size(cashflowsAtGridTime, 2) ~= nSteps + 1
        error('cashflowsAtGridTime dimensions are inconsistent with the tree grid.');
    end

    V = zeros(nNodes, nSteps + 1);

    % Extract transition probabilities and destinations directly
    pu  = tree.fit.probUp;
    pm  = tree.fit.probMid;
    pd  = tree.fit.probDn;

    up  = tree.fit.destUp;
    mid = tree.fit.destMid;
    dn  = tree.fit.destDn;

    nodeDF = tree.fit.nodeDF; % Calibrated local discount factors

    % Iterate backwards from maturity to present
    for i = nSteps:-1:1
        % Compute expected continuation value
        cont = pu .* V(up, i+1) + pm .* V(mid, i+1) + pd .* V(dn, i+1);
        
        % Value at current node = Local injected cash flow + Discounted continuation
        V(:, i) = cashflowsAtGridTime(:, i) + nodeDF(:, i) .* cont;
    end
end