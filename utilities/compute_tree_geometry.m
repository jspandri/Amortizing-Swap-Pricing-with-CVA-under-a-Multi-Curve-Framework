function [pu, pm, pd, idx_u, idx_m, idx_d] = compute_tree_geometry(x_grid, l_max, mu_hat)
% COMPUTE_TREE_GEOMETRY Precomputes transition probabilities and target indices.
%
% This function determines the transition probabilities and the destination
% nodes for a trinomial tree, implementing the standard Hull-White branching 
% logic with specific adjustments at the boundaries (top and bottom edges 
% of the grid) to maintain stability.
%
% INPUTS:
%   x_grid             : [Vector, N_nodes x 1] Spatial grid nodes.
%   l_max              : [Scalar] Maximum number of spatial nodes from the center.
%   mu_hat             : [Scalar] Deterministic drift adjustment (1 - exp(-a*dt)).
%
% OUTPUTS:
%   pu, pm, pd         : [Vectors, N_nodes x 1] Transition probabilities.
%   idx_u, idx_m, idx_d: [Vectors, N_nodes x 1] 1-based MATLAB indices for branching.

    % 1. INITIALIZATION
    N_nodes = length(x_grid);
    l = (-l_max : l_max)'; % Spatial index vector centered at 0
    
    pu = zeros(N_nodes, 1); pm = zeros(N_nodes, 1); pd = zeros(N_nodes, 1);
    k_idx = zeros(N_nodes, 1);
    idx_A = 2 : N_nodes - 1; % Central nodes where standard branching applies
    
    % 2. COMPUTE TRANSITION PROBABILITIES 
    % The drift term M = l * mu_hat is used to match the first and second 
    % moments of the Hull-White stochastic process.
    M = l * mu_hat;
    
    % A. Standard branching (Interior Nodes)
    pu(idx_A) = 1/6 + 0.5 * (M(idx_A).^2 - M(idx_A));
    pm(idx_A) = 2/3 - M(idx_A).^2;
    pd(idx_A) = 1/6 + 0.5 * (M(idx_A).^2 + M(idx_A));
    
    % B. Lower Boundary Adjustment (Edge Node 1)
    % Branching shifts to prevent the process from exiting the predefined grid.
    pu(1) = 1/6 + 0.5 * (M(1)^2 + M(1)); 
    pm(1) = -1/3 - M(1)^2 - 2 * M(1); 
    pd(1) = 7/6 + 0.5 * (M(1)^2 + 3 * M(1));
    
    % C. Upper Boundary Adjustment (Edge Node N)
    pu(end) = 7/6 + 0.5 * (M(end)^2 - 3 * M(end)); 
    pm(end) = -1/3 - M(end)^2 + 2 * M(end); 
    pd(end) = 1/6 + 0.5 * (M(end)^2 - M(end));
    
    % 3. DETERMINE TARGET CENTER NODES
    % Calculate the indices of the 'middle' destination of each branch
    k_idx(idx_A) = l(idx_A);
    k_idx(1)     = -l_max + 1; % Stay at bottom edge or move up
    k_idx(end)   =  l_max - 1; % Stay at top edge or move down
    
    % 4. MAP TO 1-BASED MATLAB INDICES
    % Translate relative spatial indices (k_idx) to 1-based array indices
    % for use in the backward induction rollback:
    % idx_u: Up node (+1), idx_m: Mid node (0), idx_d: Down node (-1)
    idx_u = k_idx + 1 + l_max + 1;
    idx_m = k_idx + l_max + 1;
    idx_d = k_idx - 1 + l_max + 1;
end