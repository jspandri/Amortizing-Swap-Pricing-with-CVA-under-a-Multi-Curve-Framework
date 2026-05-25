function [CVA, EE_profile] = calculate_cva_bachelier(settlement, scheduleSwap, estCurv, euliborCurv, volData, hazardRate, recoveryRate,K)
    % CALCULATE_CVA_BACHELIER Computes the Credit Value Adjustment (CVA)
    % for an amortizing swap using the Bachelier swaption pricing model.
    %
    % Inputs:
    %   settlement   - Settlement date (datenum)
    %   scheduleSwap - Struct containing swap amortizing plan
    %   estCurv      - Struct with OIS curve (discount_factors)
    %   euliborCurv  - Struct with Euribor 3M curve (discount_factors)
    %   volData      - Struct with implied volatility matrix
    %   hazardRate   - Constant intensity of default (lambda), e.g., 0.02 for 2%
    %   recoveryRate - Expected recovery rate (R), e.g., 0.40 for 40%
    %
    % Outputs:
    %   CVA          - Total Credit Value Adjustment in EUR
    %   EE_profile   - Vector of Expected Exposures at each payment date

    numPeriods = length(scheduleSwap.payDates);
    CVA = 0;
    
    % Pre-allocate the Expected Exposure profile (useful for plotting)
    EE_profile = zeros(numPeriods, 1);
    
    % Initial Survival Probability at t_0 (Settlement Date) is exactly 100%
    SP_prev = 1.0; 
    
    % Loop through each possible default date (which we assume happens at t_i)
    for i = 1:numPeriods
        % PROBABILITY OF DEFAULT (Marginal PD for the current interval
        T_i = yearfrac(settlement, datenum(scheduleSwap.payDates(i)), 3); % ACT/365
        
        % Survival probability up to T_i using constant hazard rate
        SP_curr = exp(-hazardRate * T_i);
        
        % Marginal Probability of Default between t_{i-1} and t_i
        PD_i = SP_prev - SP_curr;
       
        % EXPECTED EXPOSURE (Swaption Pricing via BPV Matching)
        % Call your Bachelier pricing function for default at step 'i'
        % The target swap residual life ends at 'numPeriods' (omega)
        [swaptionPrice, ~, ~, ~] = price_swap_bachelier(...
            settlement, i, numPeriods, scheduleSwap, estCurv, euliborCurv, volData,K);
        
        % Store the Expected Exposure (EE) for this period
        EE_profile(i) = swaptionPrice;
        
        % CVA ACCUMULATION
        % Loss Given Default (LGD) is (1 - Recovery Rate)
        CVA = CVA + (1 - recoveryRate) * EE_profile(i) * PD_i;
        
        % Update the previous survival probability for the next iteration
        SP_prev = SP_curr;
    end
end