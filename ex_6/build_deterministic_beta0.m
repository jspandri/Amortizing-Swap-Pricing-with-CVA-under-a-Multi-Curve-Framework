function spreadData = build_deterministic_beta0(settlement, floatStartDates, floatEndDates, discountCurve, pseudoCurve)
    

    floatStartDates = floatStartDates(:);
    floatEndDates   = floatEndDates(:);

    if length(floatStartDates) ~= length(floatEndDates)
        error('floatStartDates e floatEndDates devono avere la stessa lunghezza.');
    end

    if any(floatEndDates <= floatStartDates)
        error('Tutte le end dates devono essere successive alle start dates.');
    end

    % OIS discount factors
    Pd_start = get_discount_factor_by_zero_rates_linear_interp( ...
        settlement, floatStartDates, ...
        discountCurve.dates, discountCurve.discounts);

    Pd_end = get_discount_factor_by_zero_rates_linear_interp( ...
        settlement, floatEndDates, ...
        discountCurve.dates, discountCurve.discounts);

    % Pseudo-discount factors
    Pp_start = get_discount_factor_by_zero_rates_linear_interp( ...
        settlement, floatStartDates, ...
        pseudoCurve.dates, pseudoCurve.discounts);

    Pp_end = get_discount_factor_by_zero_rates_linear_interp( ...
        settlement, floatEndDates, ...
        pseudoCurve.dates, pseudoCurve.discounts);

    % Forward discount and pseudo-discount factors
    Bd_fwd = Pd_end ./ Pd_start;
    Bp_fwd = Pp_end ./ Pp_start;

    % Deterministic multiplicative spread
    beta0 = Bd_fwd ./ Bp_fwd;

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