function tree = setup_mhw_tree(settlementDate, lastDate, stepsPerYear, ...
    a, sigma, discountCurve, pseudoCurve, floatStartDates, floatEndDates)
% SETUP_MHW_TREE Initializes the temporal and spatial grid for a Hull-White Trinomial Tree.
%
% This function builds a uniform time grid and a discrete spatial grid for the 
% Hull-White short rate model under the multi-curve framework (with the 
% assumption gamma = 0).
% It performs numerical date-to-grid mapping for floating cash flows and 
% precomputes initial deterministic adjustment factors.
%
% INPUTS:
%   settlementDate     : [Scalar] Settlement date (datenum).
%   lastDate           : [Scalar] Maturity date of the contract (datenum).
%   stepsPerYear       : [Scalar] Time grid resolution parameter (number of discrete steps per annual interval).
%   a                  : [Scalar] Speed of mean reversion parameter for the Hull-White stochastic process.
%   sigma              : [Scalar] Volatility parameter for the Hull-White stochastic process.
%   discountCurve      : [Struct] Market OIS curve (.dates, .discounts).
%   pseudoCurve        : [Struct] Market Euribor curve (.dates, .discounts).
%   floatStartDates    : [Vector] Start dates of each floating accrual period.
%   floatEndDates      : [Vector] End dates of each floating accrual period.
%
% OUTPUTS:
%   tree               : [Struct] Tree data structure containing grid arrays, model parameters, 
%                        discrete branching thresholds, calendar mappings, and deterministic spreads.

    % Validate that stepsPerYear is a strictly positive integer value to prevent numerical errors
    if stepsPerYear <= 0 || abs(stepsPerYear - round(stepsPerYear)) > 1e-12
        error('stepsPerYear must be a positive integer.');
    end
    
    % Force settlementDate and lastDate to be a scalar by extracting their first element
    settlementDate = settlementDate(1);
    lastDate       = lastDate(1);
    
    % Ensure chronological order: the maturity date must strictly succeed the settlement date
    if lastDate <= settlementDate
        error('lastDate must succeed the settlement date.');
    end

    % TEMPORAL GRID GENERATION (Uniform time tracking)
    
    % Compute total time horizon in years from settlement to maturity using the Act/365 convention
    T_mat = yearfrac(settlementDate, lastDate, 3);
    
    % Determine the total number of discrete time steps, forcing a minimum
    % of 1 and rounding up to the nearest integer
    nSteps = max(1, ceil(T_mat * stepsPerYear));
    
    % Calculate the constant time increment (dt) ensuring the final maturity 
    % matches the last step 
    dt       = T_mat / nSteps;
    
    % Create the column vector of uniformly spaced time values from 0 to T_mat
    timeGrid = (0:nSteps)' * dt;
    
    % Convert the time grid in calendar dates
    gridDates = settlementDate + 365 * timeGrid;
    
    % Calculate the incremental steps between time grid element to verify correctness
    dtVec = diff(timeGrid);
    
    % Validation check: Ensure the time grid is strictly monotonic and increasing
    if any(dtVec <= 0)
        error('The time grid must be monotonic and increasing .');
    end
    
    % Validation check: Confirm that all time slices are perfectly uniform 
    % within tolerances
    if any(abs(dtVec - dt) > 1e-14)
        error('The time grid is not uniform.');
    end

    % ORNSTEIN-UHLENBECK STOCHASTIC GEOMETRY 
    
    % Compute the constant attenuation factor of the mean reversion process 
    % over the interval dt
    exp_a_dt = exp(-a * dt);
    
    % Calculate the localized conditional standard deviation (sigma_hat) of the short rate process over dt
    if abs(a) > 1e-14
        % Compute Hull-White analytical parameter sigma_hat
        sigma_hat = sigma * sqrt((1 - exp(-2*a*dt)) / (2*a));
    else
        % if mean reversion is zero, we use the Brownian motion standard deviation
        sigma_hat = sigma * sqrt(dt);
    end
    
    % Set the spatial grid step size (dx) using the scaling factor sqrt(3)
    dx      = sqrt(3) * sigma_hat;
    
    % Calculate the deterministic drift adjustment term
    mu_hat    = 1 - exp_a_dt;
    
    % Calculate the maximum spatial index boundary (l_max) where standard branching shifts 
    % to non-standard (asymmetric) shapes
    l_max = ceil((1 - sqrt(2/3)) / mu_hat);
    
    % Generate the full index vector of integers spanning from -l_max to +l_max
    l = (-l_max:l_max)';
    
    % Map indices to absolute spatial states (x = l * dx) representing deviations 
    % from the deterministic drift
    x = l * dx;

    % SCHEDULE TO NUMERICAL GRID MAPPING
    
    % Force inputs into column vectors
    floatStartDates = floatStartDates(:);
    floatEndDates   = floatEndDates(:);
    
    % Compute year fractions from settlement to each start accraul period
    % date in ACT/365
    startTimes = yearfrac(settlementDate, floatStartDates, 3);
    
    % Compute year fractions from settlement to each end accraul period
    % date (= payment date) in ACT/365    
    endTimes   = yearfrac(settlementDate, floatEndDates, 3);
    
    % Initialize discrete index mapping vectors for the schedule
    startIdx = zeros(length(floatStartDates), 1);
    endIdx   = zeros(length(floatEndDates), 1);
    
    % Loop through each accrual period to find the closest step on the grid
    for k = 1:length(floatStartDates)
        % Identify the step index minimizing absolute distance to the accrual start date
        [~, startIdx(k)] = min(abs(timeGrid - startTimes(k)));
        % Identify the step index minimizing absolute distance to the accrual end date
        [~, endIdx(k)]   = min(abs(timeGrid - endTimes(k)));
    end
    
    % Validation check: Ensure cash flow timing is consistent (payment and 
    % period ends must happen after period starts)
    if any(endIdx <= startIdx)
        error(['Some period has endIdx <= startIdx. ', ...
               'Use precision_levels at least 4.']);
    end
    
    % 4) RESULTS PACKAGING
    
    % Instantiate the final tree struct
    tree = struct();
    tree.model          = 'MHW gamma=0'; % Specifies multi-curve framework setup
    tree.gamma          = 0;              % Spread between the OIS and pseudo discounting curve is deterministic
    tree.a              = a;              % Store mean reversion parameter
    tree.sigma          = sigma;          % Store volatility parameter
    tree.settlementDate = settlementDate; % Store settlement date
    tree.lastDate       = lastDate;       % Store maturity date
    tree.stepsPerYear   = stepsPerYear;   % Store original discretization density setting
    tree.timeGrid       = timeGrid;       % Store the time grid
    tree.gridDates      = gridDates;      % Store the dates grid
    tree.nSteps         = nSteps;         % Store total count of time step intervals
    tree.dt             = dt;             % Store scalar size of uniform time steps
    tree.T              = T_mat;          % Store the year fraction corresponding to maturity
    tree.exp_a_dt       = exp_a_dt;       % Store precalculated expectation attenuation factor
    tree.stdStep        = sigma_hat;      % Store sigma_hat
    tree.dx             = dx;             % Store spatial step size
    tree.mu_hat         = mu_hat;         % Store drift adjustment (mu_hat)
    tree.l_max          = l_max;          % Store boundary structural index limiting spatial state rows
    tree.l              = l;              % Store indexes column vector
    tree.x              = x;              % Store spatial layer displacement values
    tree.discountCurve  = discountCurve;  % OIS curve 
    tree.pseudoCurve    = pseudoCurve;    % Pseudo-discounting curve.
    
    % Store final mapped node indices
    tree.scheduleMap.floatStartIdx = startIdx; % Discrete time grid index vector for accrual starts
    tree.scheduleMap.floatEndIdx   = endIdx;   % Discrete time grid index vector for accrual ends
    
end