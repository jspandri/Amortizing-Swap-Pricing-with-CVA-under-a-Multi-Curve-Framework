function [npvCorporate, npvFixedLeg, npvFloatLeg] = swap_riskfree_npv(scheduleSwap, swapMarketData, K)
    % SWAP_RISKFREE_NPV_FAST Calculates the Risk-Free NPV of an amortizing IRS
    % using pre-computed market data (discounts and forward rates).
    %
    % Inputs:
    %   scheduleSwap   - Struct containing vectors of delta and notionals
    %   swapMarketData - Struct containing .B_ois and .F_forward
    %   K              - Fixed strike rate (e.g., 0.0221)
    %
    % Outputs:
    %   npvCorporate - Net NPV from the Corporate's perspective (Rec Fix, Pay Float)
    %   npvFixedLeg  - Present Value of the Fixed Leg
    %   npvFloatLeg  - Present Value of the Floating Leg

    % Extract arrays
    deltas    = scheduleSwap.delta;
    notionals = scheduleSwap.notionals;
    B_ois     = swapMarketData.B_ois;
    F_forward = swapMarketData.F_forward;
    
    % VECTORIZED CASH FLOWS
    % Element-wise multiplication '.*'
    cf_fixed = notionals .* K .* deltas;
    cf_float = notionals .* F_forward .* deltas;
    
    % DISCOUNTING & LEGS PRESENT VALUE
    npvFixedLeg = sum(cf_fixed .* B_ois);
    npvFloatLeg = sum(cf_float .* B_ois);
    
    % NET NPV (Corporate perspective)
    npvCorporate = npvFixedLeg - npvFloatLeg;
end