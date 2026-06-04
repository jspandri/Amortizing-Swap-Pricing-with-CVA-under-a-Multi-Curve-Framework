function tree = setup_mhw_tree( ...
    settlementDate, lastDate, stepsPerYear, ...
    a, sigma, discountCurve, pseudoCurve, ...
    floatStartDates, floatEndDates)
% SETUP_MHW_TREE_GAMMA0
% Tree HW/MHW gamma=0 su griglia uniforme in tempo.
%
% INPUT
%   settlementDate : datenum
%   lastDate       : datenum ultima data da coprire
%   stepsPerYear   : es. 1, 4, 12, 52, 365
%   a, sigma       : parametri HW
%   discountCurve  : curva OIS
%   pseudoCurve    : curva pseudo-discount
%   floatStartDates, floatEndDates : date dei periodi floating
%
% OUTPUT
%   tree : struttura del tree + mapping schedule->grid + beta0 iniziali

    if stepsPerYear <= 0 || abs(stepsPerYear - round(stepsPerYear)) > 1e-12
        error('stepsPerYear deve essere un intero positivo.');
    end

    settlementDate = settlementDate(1);
    lastDate       = lastDate(1);

    if lastDate <= settlementDate
        error('lastDate deve essere successiva a settlementDate.');
    end

    % ------------------------------------------------------------
    % 1) Uniform grid in TIME, non in date intere
    % ------------------------------------------------------------
    T_mat = yearfrac(settlementDate, lastDate, 3);

    % numero di step coerente con la risoluzione richiesta
    nSteps = max(1, ceil(T_mat * stepsPerYear));

    % dt costante e lastDate esattamente sulla griglia
    dt       = T_mat / nSteps;
    timeGrid = (0:nSteps)' * dt;

    % serial MATLAB anche frazionari: niente round()
    gridDates = settlementDate + 365 * timeGrid;

    dtVec = diff(timeGrid);
    if any(dtVec <= 0)
        error('timeGrid deve essere strettamente crescente.');
    end
    if any(abs(dtVec - dt) > 1e-14)
        error('La griglia costruita non e'' uniforme.');
    end

    % ------------------------------------------------------------
    % 2) Parametri OU / Tree
    % ------------------------------------------------------------
    exp_a_dt = exp(-a * dt);

    if abs(a) > 1e-14
        sigma_hat = sigma * sqrt((1 - exp(-2*a*dt)) / (2*a));
    else
        sigma_hat = sigma * sqrt(dt);
    end

    dx      = sqrt(3) * sigma_hat;

    mu_hat    = 1 - exp_a_dt;
    l_max = ceil((1 - sqrt(2/3)) / mu_hat);

    l = (-l_max:l_max)';
    x = l * dx;

    % ------------------------------------------------------------
    % 3) Mapping schedule -> grid
    % ------------------------------------------------------------

    floatStartDates = floatStartDates(:);
    floatEndDates   = floatEndDates(:);

    startTimes = yearfrac(settlementDate, floatStartDates, 3);
    endTimes   = yearfrac(settlementDate, floatEndDates, 3);
    
    for k = 1:length(floatStartDates)
        [~, startIdx(k)] = min(abs(timeGrid - startTimes(k)));
        [~, endIdx(k)]   = min(abs(timeGrid - endTimes(k)));
    end
    
    if any(endIdx <= startIdx)
        error(['Alcuni periodi hanno endIdx <= startIdx. ', ...
               'Usa precision_levels almeno trimestrali (multipli di 4).']);
    end

    beta0 = build_deterministic_beta0( ...
        settlementDate, floatStartDates, floatEndDates, ...
        discountCurve, pseudoCurve);


    % ------------------------------------------------------------
    % 4) Output
    % ------------------------------------------------------------
    tree = struct();
    tree.model          = 'MHW gamma=0';
    tree.gamma          = 0;
    tree.a              = a;
    tree.sigma          = sigma;

    tree.settlementDate = settlementDate;
    tree.lastDate       = lastDate;
    tree.stepsPerYear   = stepsPerYear;

    tree.timeGrid       = timeGrid;
    tree.gridDates      = gridDates;    % anche frazionarie
    tree.nSteps         = nSteps;
    tree.dt             = dt;
    tree.T              = T_mat;

    tree.exp_a_dt       = exp_a_dt;
    tree.stdStep        = sigma_hat;
    tree.dx             = dx;

    tree.mu_hat              = mu_hat;
    tree.l_max          = l_max;
    tree.l              = l;
    tree.x              = x;

    tree.discountCurve  = discountCurve;
    tree.pseudoCurve    = pseudoCurve;

    tree.scheduleMap.floatStartIdx = startIdx;
    tree.scheduleMap.floatEndIdx   = endIdx;

    tree.spread.beta0   = beta0;
end