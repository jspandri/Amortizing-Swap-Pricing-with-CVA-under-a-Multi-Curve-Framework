function adjustedDates = shift_2bd_backward(inputDates)
    % SHIFT_2BD_BACKWARD Shifts an array of dates backward by exactly 
    % 2 Business Days using pure array mathematics.
    % weekday() returns: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
    
    w_days = weekday(inputDates);
    shift_days = 2 * ones(size(inputDates)); % Default: shift by 2 days
    
    % Correct for weekends
    shift_days(w_days == 2 | w_days == 3) = 4; % Mon/Tue shifted to Thu/Fri
    shift_days(w_days == 1) = 3;               % Sun shifted to Thu
    
    adjustedDates = inputDates - shift_days;
end