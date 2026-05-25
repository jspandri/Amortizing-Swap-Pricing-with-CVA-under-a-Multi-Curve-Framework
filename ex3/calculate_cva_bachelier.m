function [CVA, EE_profile] = calculate_cva_bachelier(settlement, scheduleSwap, swapMarketData, volData, hazardRate, recoveryRate, K, estCurv)
    % CALCULATE_CVA_BACHELIER Computes the Credit Value Adjustment (CVA) 
    % for an amortizing swap using a fully vectorized Bachelier pricing model.
    %
    % This function calculates the expected exposure and default probabilities 
    % across all payment nodes simultaneously without the use of for-loops,
    % ensuring maximum computational efficiency.
    %
    % Inputs:
    %   settlement     - Settlement date (datenum)
    %   scheduleSwap   - Struct containing the swap amortizing schedule
    %   swapMarketData - Struct containing pre-calculated market data vectors
    %                    (e.g., P_ois_pay, F_forward)
    %   volData        - Struct containing implied volatility surface/matrix
    %   hazardRate     - Constant intensity of default (lambda), e.g., 0.02
    %   recoveryRate   - Expected recovery rate (R), e.g., 0.40
    %   K              - Strike rate for the swaptions
    %   estCurv        - Struct containing the OIS zero curve for BPV mapping
    %
    % Outputs:
    %   CVA            - Total Credit Value Adjustment (scalar)
    %   EE_profile     - Vector of Expected Exposures at each payment date
    
    % --- Date vector and time to expiry calculation (T_i) ---
    payDates_num = datenum(scheduleSwap.payDates);
    T_exp = yearfrac(settlement, payDates_num, 3); % ACT/365
    
    % --- Vectorized Survival and Default Probabilities ---
    SP = exp(-hazardRate * T_exp);
    SP_prev = [1; SP(1:end-1)]; % Forward shift to obtain SP_{i-1}
    PD = SP_prev - SP;          % Marginal Probability of Default for each node
    
    % --- EXPECTED EXPOSURE CALCULATION (Single vectorized call) ---
    % The pricing function returns the entire time profile at once!
    [EE_profile, ~, ~, ~] = price_swap_bachelier(...
        settlement, scheduleSwap, swapMarketData, volData, K, estCurv, T_exp);
        
    % --- CVA ACCUMULATION (Dot product of the vectors) ---
    % Expected Exposure * Marginal PD * Loss Given Default
    CVA = sum((1 - recoveryRate) .* EE_profile .* PD);
    
end