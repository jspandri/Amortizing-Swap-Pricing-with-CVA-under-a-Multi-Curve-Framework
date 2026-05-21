function schedule = generate_schedule_with_stub(settlement, maturity)


curr_unadj = maturity;
schedule_unadj = curr_unadj;

next_unadj = increment_date(curr_unadj, 0, 0, -1);

while next_unadj > settlement
    schedule_unadj = [next_unadj, schedule_unadj];
    curr_unadj = next_unadj;
    next_unadj = increment_date(curr_unadj, 0, 0, -1);
end    

% 2. Fase Adjusted: Applichiamo la convenzione solo alla fine
schedule_adj = zeros(size(schedule_unadj));
for i = 1:length(schedule_unadj)
    % Incremento nullo (0,0,0), sfruttiamo la funzione solo come "filtro" festività
    schedule_adj(i) = following_day_convention(schedule_unadj(i), 0, 0, 0, 1, true);
end

schedule = [settlement, schedule_adj];



end