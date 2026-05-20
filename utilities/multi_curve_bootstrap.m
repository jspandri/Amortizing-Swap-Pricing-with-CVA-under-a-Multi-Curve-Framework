function [discounts, pseudo_discounts] = multi_curve_bootstrap(euriborSet, estrSet)

settlement = estrSet.settlement;

% Discount Curve (OIS ESTR curve)

estrDates = estrSet.dates;
estrRates = estrSet.rates;

target_1y = following_day_convention(settlement, 0, 0, 1, 1, true);

idx_below_1y = (estrDates <= target_1y);

discounts = zeros(length(estrDates), 1);

delta = yearfrac(settlement, estrDates, 2);

discounts(idx_below_1y) = 1 ./ (1 + delta(idx_below_1y) .* estrRates(idx_below_1y));




end