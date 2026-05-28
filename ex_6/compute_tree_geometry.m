function [pu, pm, pd, idx_u, idx_m, idx_d] = compute_tree_geometry(x_grid, l_max, mu_hat)
% COMPUTE_TREE_GEOMETRY Precomputes transition probabilities and target indices for the tree.
% This function strictly implements the professor's notation using l, mu_hat, 
% and explicit boundary branching handling.
%
% INPUTS:
%   x_grid             : [Vector, N_nodes x 1] Spatial grid nodes column vector.
%   l_max              : [Scalar] Maximum number of spatial nodes from the center.
%   mu_hat             : [Scalar] Deterministic drift adjustment (1 - exp(-a*dt)).
%
% OUTPUTS:
%   pu, pm, pd         : [Vectors, N_nodes x 1] Transition probabilities for up, mid, down branches.
%   idx_u, idx_m, idx_d: [Vectors, N_nodes x 1] 1-based MATLAB indices for branching targets.

    N_nodes = length(x_grid);
    l = (-l_max : l_max)';
    
    pu = zeros(N_nodes, 1); pm = zeros(N_nodes, 1); pd = zeros(N_nodes, 1);
    k_idx = zeros(N_nodes, 1);
    idx_A = 2 : N_nodes - 1;
    
    % 1. COMPUTE TRANSITION PROBABILITIES (Prof Notation: M = l * mu_hat)
    M = l * mu_hat;
    
    pu(idx_A) = 1/6 + 0.5 * (M(idx_A).^2 - M(idx_A));
    pm(idx_A) = 2/3 - M(idx_A).^2;
    pd(idx_A) = 1/6 + 0.5 * (M(idx_A).^2 + M(idx_A));
    
    pu(1) = 1/6 + 0.5 * (M(1)^2 + M(1)); 
    pm(1) = -1/3 - M(1)^2 - 2 * M(1); 
    pd(1) = 7/6 + 0.5 * (M(1)^2 + 3 * M(1));
    
    pu(end) = 7/6 + 0.5 * (M(end)^2 - 3 * M(end)); 
    pm(end) = -1/3 - M(end)^2 + 2 * M(end); 
    pd(end) = 1/6 + 0.5 * (M(end)^2 - M(end));

    % 2. DETERMINE TARGET CENTER NODES (Relative k_idx)
    k_idx(idx_A) = l(idx_A);
    k_idx(1) = -l_max + 1;
    k_idx(end) = l_max - 1;
    
    % 3. MAP TO 1-BASED MATLAB INDICES
    idx_u = k_idx + 1 + l_max + 1;
    idx_m = k_idx + l_max + 1;
    idx_d = k_idx - 1 + l_max + 1;
end