function [time_grid, grid_dates, dt] = build_hw_time_grid(startDate, maturityDate, stepsPerYear)
% BUILD_HW_TIME_GRID Generates a uniform time grid for Hull-White trinomial tree pricing.
%
%
% INPUTS:
%   startDate     - [Datetime/Datenum] Valuation/start date
%   maturityDate  - [Datetime/Datenum] Final maturity
%   stepsPerYear  - [Scalar] Number of time steps per year 
%                   
% OUTPUTS:
%   time_grid     - [N x 1] Times in years (Act/365), strictly increasing
%   grid_dates    - [N x 1] Dates (datenums), linear Act/365 conversion
%   dt            - [Scalar] Constant time step size
    
    % 1. UNIFY INPUT TYPES
    startDate    = datenum(startDate);
    maturityDate = datenum(maturityDate);
    
    % 2. TOTAL HORIZON (Act/365 convention)
    T_max_y = yearfrac(startDate, maturityDate, 3);
    
    % 3. CALCULATE CONSTANT DT
    % Ensure at least one step 
    exact_steps = max(1, T_max_y * stepsPerYear);
    N_steps = ceil(exact_steps);
    dt = T_max_y / N_steps;
    
    % 4. GENERATE UNIFORM TIME GRID (Years)
    time_grid = linspace(0, T_max_y, N_steps + 1)';
    
    % 5. CORRESPONDING DATENUMS
    grid_dates = startDate + time_grid * 365;
end
