function [npvCorporate, npvFixedLeg, npvFloatLeg] = swap_riskfree_npv_vectorized(settlement, scheduleSwap, estCurv, euliborCurv)
    % SWAP_RISKFREE_NPV_VECTORIZED Calculates the Risk-Free NPV of an amortizing IRS
    %   using a fully vectorized approach without for-loops.
    %
    % Inputs:
    %   settlement   - Settlement date (datenum or datetime)
    %   scheduleSwap - Struct containing vectors of payDates, accrualStart, 
    %                  accrualEnd, delta, and notionals.
    %   estCurv      - Struct with OIS curve data (.dates and .discount_factors)
    %   euliborCurv  - Struct with Euribor 3M data (.dates and .discount_factors)
    %
    % Outputs:
    %   npvCorporate - Net NPV from the Corporate's perspective
    %   npvFixedLeg  - Present Value of the Fixed Leg
    %   npvFloatLeg  - Present Value of the Floating Leg

    % Fixed strike rate from the Swap Termsheet
    K = 0.0221; 
    
    % Ensure dates are in datenum format to avoid interpolation errors
    startDates = datenum(scheduleSwap.accrualStart);
    endDates   = datenum(scheduleSwap.accrualEnd);
    payDates   = datenum(scheduleSwap.payDates);
    
    % Extract arrays for fast vectorized operations
    deltas    = scheduleSwap.delta;
    notionals = scheduleSwap.notionals;
    
    % DISCOUNTING: ESTR / OIS Curve
    B_ois = get_discount_factor_by_zero_rates_linear_interp(...
        settlement, payDates, estCurv.dates, estCurv.discounts);
        
    % FORECASTING: Euribor 3M Curve
    %non sono sicuro che se calcolo L_forward devo iniziare da 2 BD prima ?
    P_euri_start = get_discount_factor_by_zero_rates_linear_interp(...
        settlement, startDates, euliborCurv.dates, euliborCurv.discounts);
        
    P_euri_end = get_discount_factor_by_zero_rates_linear_interp(...
        settlement, endDates, euliborCurv.dates, euliborCurv.discounts);
        
    % Compute the forward rates for all periods simultaneously
    F_forward = (1 ./ deltas) .* (P_euri_start ./ P_euri_end - 1);

    % VECTORIZED CASH FLOWS & NPV CALCULATION
    % Compute all cash flows (element-wise multiplication '.*')
    cf_fixed = notionals .* K .* deltas;
    cf_float = notionals .* F_forward .* deltas;
    
    % Discount all cash flows and sum them up
    npvFixedLeg = sum(cf_fixed .* B_ois);
    npvFloatLeg = sum(cf_float .* B_ois);
    
    % NET NPV (Corporate perspective: Receives Fixed, Pays Floating)
    npvCorporate = npvFixedLeg - npvFloatLeg;

end