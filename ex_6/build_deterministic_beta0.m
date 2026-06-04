function spreadData = build_deterministic_beta0(settlement, floatStartDates, ...
    floatEndDates, discountCurve, pseudoCurve)
% BUILD_DETERMINISTIC_BETA0 Computes the multi-curve deterministic adjustment 
% factor (beta) to link the OIS discounting curve with the pseudo discounting curve.
%
% INPUTS:
%   settlement      : [Scalar] Valuation date (datenum).
%   floatStartDates : [Vector] Start dates of the floating periods.
%   floatEndDates   : [Vector] End dates of the floating periods.
%   discountCurve   : [Struct] OIS market curve (.dates, .discounts).
%   pseudoCurve     : [Struct] Pseudo-discount market curve (.dates, .discounts).
%
% OUTPUTS:
%   spreadData      : [Struct] Contains the calculated discount factors,
%                     forward discount factors, and the resulting beta vector.

    % Force inputs to column vectors to ensure compatibility
    floatStartDates = floatStartDates(:);
    floatEndDates   = floatEndDates(:);

    % Input validation to ensure schedule consistency
    if length(floatStartDates) ~= length(floatEndDates)
        error('floatStartDates and floatEndDates must have the same length.');
    end
    if any(floatEndDates <= floatStartDates)
        error('All end dates must be strictly after start dates.');
    end

    % 1. EXTRACT OIS DISCOUNT FACTORS ---
    % Get discount factors from the OIS curve at start and end dates
    Pd_start = get_discount_factor_by_zero_rates_linear_interp( ...
        settlement, floatStartDates, discountCurve.dates, discountCurve.discounts);
    
    Pd_end = get_discount_factor_by_zero_rates_linear_interp( ...
        settlement, floatEndDates, discountCurve.dates, discountCurve.discounts);

    % 2. EXTRACT PSEUDO-DISCOUNT FACTORS 
    % Get discount factors from the pseudo discounting curve at start and end dates
    Pp_start = get_discount_factor_by_zero_rates_linear_interp( ...
        settlement, floatStartDates, pseudoCurve.dates, pseudoCurve.discounts);
    
    Pp_end = get_discount_factor_by_zero_rates_linear_interp( ...
        settlement, floatEndDates, pseudoCurve.dates, pseudoCurve.discounts);

    % 3. COMPUTE FORWARD DISCOUNT FACTORS
    % Calculate the OIS-based forward discount factor: P_D(T_start, T_end)
    Bd_fwd = Pd_end ./ Pd_start;
    
    % Calculate the Pseudo-based forward discount factor: P_P(T_start, T_end)
    Bp_fwd = Pp_end ./ Pp_start;

    % 4. CALCULATE DETERMINISTIC BETA FACTOR 
    % Beta0 is the ratio of OIS forward discounts and Pseudo forward discounts.
    beta0 = Bd_fwd ./ Bp_fwd;

    % 5. PACKAGE OUTPUT
    % Store all computed data in a structured object
    spreadData = struct();
    spreadData.floatStartDates = floatStartDates;
    spreadData.floatEndDates   = floatEndDates;
    spreadData.Pd_start = Pd_start;
    spreadData.Pd_end   = Pd_end;
    spreadData.Pp_start = Pp_start;
    spreadData.Pp_end   = Pp_end;
    spreadData.Bd_fwd   = Bd_fwd;
    spreadData.Bp_fwd   = Bp_fwd;
    spreadData.beta0    = beta0;
end