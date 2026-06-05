function pay_dates_bullet_mat = generate_exact_quarterly_dates(expiry_date, num_quarters, modified)
% GENERATE_EXACT_QUARTERLY_DATES Generates an exact grid of future quarterly payment dates and automatically adjusts them to valid business days.
%
% INPUTS:
%   expiry_date                : [Vector] Vector of starting dates in datenum format (N x 1)
%   num_quarters               : [Scalar] Number of future quarters to generate (Scalar, Q)
%   modified                   : [Boolean] (Optional) true for 'modifiedfollow', false for 'follow'. 
%                                          Default is true.
%
% OUTPUTS:
%   pay_dates_bullet_mat       : [Matrix] Matrix of adjusted business dates in datenum format (N x Q)

    % Default to Modified Following if not specified
    if nargin < 3
        modified = true; 
    end
    
    if modified
        rule = "modifiedfollow";
    else
        rule = "follow";
    end
    
    % Dummy holidays (weekends only) to replicate standard market conventions
    holidays = datenum("01-Jan-2000");

    % --- 1. Data Sanitization (Error Prevention) ---
    expiry_date = expiry_date(:);
    
    if iscell(expiry_date)
        expiry_date = cell2mat(expiry_date);
    end
    if isdatetime(expiry_date)
        expiry_date = datenum(expiry_date);
    end
    if ~isnumeric(expiry_date)
        try
            expiry_date = datenum(expiry_date);
        catch
            error('generate_exact_quarterly_dates:InvalidDate', ...
                  'Invalid date format passed to generator. Please provide datenum format.');
        end
    end
    
    % Ensure pure double array
    expiry_date = double(expiry_date);
    
    % Exact Calendar Calculation 
    dt_expiry = datetime(expiry_date, 'ConvertFrom', 'datenum');
    
    % Generate a 1xQ row vector of months to add (3, 6, 9, 12...)
    months_to_add = calmonths(3 * (1:num_quarters));
    
    % Broadcasting: (N x 1) + (1 x Q) = Exact (N x Q) calendar date matrix
    dt_matrix = dt_expiry + months_to_add;
    
    % Reconvert to numeric datenum format for business day adjustment
    raw_dates_num = datenum(dt_matrix);
    
    % Massive Vectorized Business Day Adjustment 
    % 'busdate' evaluates the entire N x Q matrix simultaneously.
    % Shifts dates falling on weekends according to the selected rule.
    pay_dates_bullet_mat = busdate(raw_dates_num, rule, holidays);
end