function tree = fit_hw_tree_ois(settlement, tree)
% FIT_HW_TREE_OIS
% Fit della curva OIS iniziale via Arrow-Debreu prices sul tree uniforme.


    gridDates = tree.gridDates(:);
    timeGrid  = tree.timeGrid(:);
    nSteps    = tree.nSteps;
    dt        = tree.dt;

    l         = tree.l(:);
    x         = tree.x(:);
    l_max      = tree.l_max;
    mu_hat         = tree.mu_hat;

    nNodes    = length(l);
    idx0      = l_max + 1;

    discCurve = tree.discountCurve;

    % ------------------------------------------------------------
    % Market discount factors P(0,t_i)
    % ------------------------------------------------------------
    marketDF = get_discount_factor_by_zero_rates_linear_interp( ...
        settlement, gridDates, ...
        discCurve.dates, discCurve.discounts);
    marketDF = marketDF(:);

    if length(marketDF) ~= nSteps + 1
        error('marketDF deve avere lunghezza nSteps+1.');
    end

    % ------------------------------------------------------------
    % Build transitions with A/B/C branching
    % ------------------------------------------------------------
    destUp  = zeros(nNodes,1);
    destMid = zeros(nNodes,1);
    destDn  = zeros(nNodes,1);

    probUp  = zeros(nNodes,1);
    probMid = zeros(nNodes,1);
    probDn  = zeros(nNodes,1);

    for k = 1:nNodes
        l_k  = l(k);
        mu_l = mu_hat * l_k;

        if l_k > -l_max && l_k < l_max
            % --------------------------
            % Interior node: branching A
            % Destinations: j+1, j, j-1
            % --------------------------
            destUp(k)  = k + 1;
            destMid(k) = k;
            destDn(k)  = k - 1;

            probUp(k)  = 1/6 + 0.5 * (mu_l^2 - mu_l);
            probMid(k) = 2/3 - mu_l^2;
            probDn(k)  = 1/6 + 0.5 * (mu_l^2 + mu_l);

        elseif l_k == -l_max
            % --------------------------
            % Lower boundary: branching B
            % Destinations: j+2, j+1, j
            % --------------------------
            destUp(k)  = k + 2;
            destMid(k) = k + 1;
            destDn(k)  = k;

            probUp(k)  = 1/6 + 0.5 * (mu_l^2 + mu_l);
            probMid(k) = -1/3 - mu_l^2 - 2*mu_l;
            probDn(k)  = 7/6 + 0.5 * (mu_l^2 + 3*mu_l);

        elseif l_k == l_max
            % --------------------------
            % Upper boundary: branching C
            % Destinations: j, j-1, j-2
            % --------------------------
            destUp(k)  = k;
            destMid(k) = k - 1;
            destDn(k)  = k - 2;

            probUp(k)  = 7/6 + 0.5 * (mu_l^2 - 3*mu_l);
            probMid(k) = -1/3 - mu_l^2 + 2*mu_l;
            probDn(k)  = 1/6 + 0.5 * (mu_l^2 - mu_l);

        else
            error('Indice di nodo fuori dominio.');
        end
    end

    % Safety checks
    if any(destUp < 1 | destUp > nNodes) || ...
       any(destMid < 1 | destMid > nNodes) || ...
       any(destDn < 1 | destDn > nNodes)
        error('Transizioni fuori dominio: controlla branching A/B/C.');
    end

    probsSum = probUp + probMid + probDn;
    if any(abs(probsSum - 1) > 1e-12)
        error('Le probabilita'' di transizione non sommano a 1.');
    end

    if any(probUp < -1e-14) || any(probMid < -1e-14) || any(probDn < -1e-14)
        error('Probabilita'' negative nel tree: controlla jMax/M.');
    end

   
    statePrices = zeros(nNodes, nSteps + 1);
    statePrices(idx0, 1) = 1.0;

    alpha      = zeros(nSteps,1);
    shortRates = zeros(nNodes,nSteps);
    nodeDF     = zeros(nNodes,nSteps);

    for i = 1:nSteps
        q_i = statePrices(:, i);

        numer = sum(q_i .* exp(-x * dt));
        alpha(i) = log(numer / marketDF(i+1)) / dt;

        shortRates(:, i) = x + alpha(i);
        nodeDF(:, i)     = exp(-shortRates(:, i) * dt);

        contrib = q_i .* nodeDF(:, i);

        q_next = zeros(nNodes,1);
        for j = 1:nNodes
            w = contrib(j);
        
            q_next(destUp(j))  = q_next(destUp(j))  + w * probUp(j);
            q_next(destMid(j)) = q_next(destMid(j)) + w * probMid(j);
            q_next(destDn(j))  = q_next(destDn(j))  + w * probDn(j);
        end

        statePrices(:, i+1) = q_next;
    end

    modelDF = sum(statePrices, 1)';

    % ------------------------------------------------------------
    % Save results
    % ------------------------------------------------------------
    tree.fit.marketDF    = marketDF;
    tree.fit.modelDF     = modelDF;
    tree.fit.absErrDF    = modelDF - marketDF;
    tree.fit.relErrDF    = (modelDF - marketDF) ./ max(marketDF, 1e-16);

    tree.fit.alpha       = alpha;
    tree.fit.shortRates  = shortRates;
    tree.fit.nodeDF      = nodeDF;
    tree.fit.statePrices = statePrices;

    tree.fit.destUp      = destUp;
    tree.fit.destMid     = destMid;
    tree.fit.destDn      = destDn;

    tree.fit.probUp      = probUp;
    tree.fit.probMid     = probMid;
    tree.fit.probDn      = probDn;

    tree.fit.timeGrid    = timeGrid;
    tree.fit.gridDates   = gridDates;
end