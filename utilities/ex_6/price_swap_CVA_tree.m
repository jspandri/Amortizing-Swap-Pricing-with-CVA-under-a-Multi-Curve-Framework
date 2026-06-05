function [price, price_clean, CVA, details, tree] = price_swap_CVA_tree( ...
    a, sigma, K, settlement, scheduleSwap, stepsPerYear, ...
    RecoveryRate, HazardRates, discountCurve, pseudoCurve)
% PRICE_SWAP_CVA_TREE Prices an amortizing Swap and computes its CVA using a calibrated Hull-White Tree.
%
% This function manages the construction, market calibration, and backward 
% induction pricing of an amortizing swap under a multi-curve framework 
% (under gamma = 0 hypothesis). 
%
% INPUTS:
%   a                  : [Scalar] Speed of mean reversion in the Hull-White model.
%   sigma              : [Scalar] Volatility parameter in the Hull-White model.
%   K                  : [Scalar] Fixed strike rate of the swap.
%   settlement         : [Scalar] Settlement date (datenum).
%   scheduleSwap       : [Struct] Swap schedule container with active periods:
%                                  - .accrualStart : Period start dates (datenum)
%                                  - .accrualEnd   : Period end dates (datenum)
%                                  - .payDates     : Coupon payment dates (datenum)
%                                  - .notionals    : Active outstanding amortizing notionals
%                                  - .yf_pay       : Year fractions for payment periods (ACT/360)
%                                  - .F_forward    : Forward Libor rates
%                                  - .B_ois        : discounts at payments dates
%   stepsPerYear       : [Scalar] Number of time steps per year.
%   RecoveryRate               : [Scalar] Recovery rate in case of default.
%   HazardRates                : [Vectir] Constant hazard rates (lambda) for default probability.
%   discountCurve              : [Struct] Market OIS curve (.dates, .discounts).
%   pseudoCurve                : [Struct] Market Euribor curve (.dates, .discounts).
%
% OUTPUTS:
%   price              : [Vector] Risky Net Present Value (NPV) of the swap, accounting for CVA.
%   price_clean        : [Scalar] Risk-free (clean) Net Present Value (NPV) of the swap.
%   CVA                : [Vector] Credit Valuation Adjustment.
%   details            : [Struct] Multi-layered structure storing raw pricing 
%                                 data, exposures, and cash flow details.
%   tree               : [Struct] Tree object containing grid geometries, 
%                                 transition probabilities, and calibrated parameters.

    % Extract the maturity date from the swap schedule (corresponding to the final payment date)
    maturityDate = scheduleSwap.payDates(end);

    % TREE GEOMETRY AND MAPPING SETUP
    % Generate the uniform time grid and spatial grid. This function maps 
    % the floating/fixed schedule dates onto the closest numerical tree nodes 
    % by minimizing absolute distance.
    % It also precomputes the initial deterministic forward adjustments (beta0 vectors).
    tree = setup_mhw_tree(settlement, maturityDate, stepsPerYear, ...
        a, sigma, discountCurve, pseudoCurve, scheduleSwap.accrualStart, ...
        scheduleSwap.accrualEnd);
    
    % MARKET CURVE CALIBRATION (FORWARD INDUCTION)
    % Perform market fitting via state prices. 
    % We calculate the time-varying deterministic drift vector (alpha_i) 
    % required to replicate initial OIS discount factors exactly, establishing 
    % an arbitrage-free pricing structure.
    tree = fit_hw_tree_ois(settlement, tree);

    % BACKWARD INDUCTION
    % Execute the backward induction on the calibrated tree (considering a
    % vector of hazard rates)
    [price_clean, ~, ~, CVA, price, details] = swap_npv_cva_tree( ...
        settlement, tree, scheduleSwap, K, HazardRates, RecoveryRate);

end