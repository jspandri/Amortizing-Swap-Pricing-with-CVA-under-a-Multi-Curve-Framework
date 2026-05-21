function [discounts, pseudo_discounts] = multi_curve_bootstrap(euriborSet, estrSet)

settlement = estrSet.settlement;

% Discount Curve (OIS ESTR curve)

estrDates = estrSet.dates;
estrRates = estrSet.rates;

target_1y = following_day_convention(settlement, 0, 0, 1, 1, true);

idx_below_1y = (estrDates <= target_1y);
idx_above_1y = find(~idx_below_1y);

discounts = zeros(length(estrDates), 1);

delta = yearfrac(settlement, estrDates, 2);

discounts(idx_below_1y) = 1 ./ (1 + delta(idx_below_1y) .* estrRates(idx_below_1y));


for i = 1:length(idx_above_1y)

    idx = idx_above_1y(i);
    T = estrDates(idx);
    R_ois = estrRates(idx);

    schedule = generate_schedule_with_stub(settlement, T);
    t_prev = schedule(1);

    fixed_leg = 0;

    for k = 2:length(schedule)

        t_curr = schedule(k);

        delta_k = yearfrac(t_prev, t_curr, 2);

        if k < length(schedule)

            t_known = estrDates(1:idx-1);
            discounts_known = discounts(1:idx-1);
    
            discount_k = get_discount_factor_by_zero_rates_linear_interp(settlement, t_curr, t_known, discounts_known);
    
            fixed_leg = fixed_leg + delta_k * discount_k;
        end    

        t_prev = t_curr;
            
    end    

    discounts(idx) = (1 - R_ois * fixed_leg) / (1 + delta_k * R_ois);

end  

pseudo_discounts = [];

end