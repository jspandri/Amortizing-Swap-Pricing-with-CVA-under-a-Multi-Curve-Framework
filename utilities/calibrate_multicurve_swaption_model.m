function [outputArg1,outputArg2] = calibrate_multicurve_swaption_model(settlement, discountCurve, pseudoCurve, vol_data, diag_expiries, diag_tenors)


vol_matrix = vol_data.vol_matrix;
strike = vol_data.strike;
expiries = vol_data.expiries;
tenors = vol_data.tenors;

discounts = discountCurve.discounts;
disc_dates = discountCurve.dates;
pseudo_discounts = pseudoCurve.discounts;
pseudo_dates = pseudoCurve.dates;

n_swaptions = length(diag_expiries);

mkt_vols = zeros(n_swaptions, 1);
mkt_prices = zeros(n_swaptions, 1);

for i = 1:n_swaptions

    expiry = diag_expiries(i);
    tenor = diag_tenors(i);

    idx_row = find(expiries == expiry, 1);
    idx_col = find(tenors == tenor, 1);

    if isempty(idx_row) || isempty(idx_col)
        error('Volatility data for Swaption %gY%gY not found.', expiry, tenor)
   end

    mkt_vol = vol_matrix(idx_row, idx_col);
    mkt_vols(i) = mkt_vol;

    if (expiry < 1)
        months_expiry = expiry * 12;
        years_expiry = 0;
    else
        months_expiry = 0;
        years_expiry = expiry;
    end 

    expiry_date = following_day_convention(settlement, 0, months_expiry, years_expiry, 1, true);

    discount_expiry = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
                        expiry_date, disc_dates, discounts);

    swap_rate = compute_fwd_swap_rate(settlement, expiry, tenor, discountCurve, pseudoCurve);

    if abs(swap_rate) > 1e-8
        cash_annuity = (1 / swap_rate) * (1 - 1 / (1 + swap_rate)^tenor);
    else
        cash_annuity = tenor; 
    end

    t_alpha = yearfrac(settlement, expiry_date, 3);

    d = (swap_rate - strike) / (mkt_vol * sqrt(t_alpha));

    mkt_prices(i) = discount_expiry * cash_annuity * ((strike - swap_rate) * normcdf(-d) ...
                        + mkt_vol * sqrt(t_alpha) * normpdf(d));
end    



end