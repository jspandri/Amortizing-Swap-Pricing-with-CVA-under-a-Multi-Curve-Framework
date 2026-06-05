function schedule = generate_schedule_with_stub(settlement, maturity)
% Generate schedule of yearly payment dates considering short stub in
% advance (found in backward way, starting from maturity).
%
% INPUTS:
%   settlement          - settlement date.
%   maturity            - maturity date.
%
% OUTPUTS:
%   schedule            - vector of payment dates.


curr_unadj = maturity;
schedule_unadj = curr_unadj;
next_unadj = increment_date(curr_unadj, 0, 0, -1);

% Subtract yearly dates from maturity till it reaches settlement date.
while next_unadj > settlement
    schedule_unadj = [next_unadj; schedule_unadj];
    curr_unadj = next_unadj;
    next_unadj = increment_date(curr_unadj, 0, 0, -1);
end    

% Fix dates with modified-following convention
schedule_adj = zeros(size(schedule_unadj));
for i = 1:length(schedule_unadj)
    schedule_adj(i) = following_day_convention(schedule_unadj(i), 0, 0, 0, 1, true);
end

schedule = [settlement; schedule_adj];

end