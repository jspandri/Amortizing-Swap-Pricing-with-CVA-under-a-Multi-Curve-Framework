function idx = find_future_idx(settlement, futures_starts, starting_month)


[settle_year, settle_month, ~] = datevec(settlement);

settle_month_third_wed = thirdwednesday(settle_month, settle_year);

if settlement < settle_month_third_wed
    months_increment = starting_month - 1;
else
    months_increment = starting_month;
end    

date_target_month = increment_date(settlement, 0, months_increment, 0);
[target_year, target_month, ~] = datevec(date_target_month);

target_start = thirdwednesday(target_month, target_year);

idx = find(futures_starts == target_start, 1);

if isempty(idx)
    error("No future found with requested starting date.");
end

end