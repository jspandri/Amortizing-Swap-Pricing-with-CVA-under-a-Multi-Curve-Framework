function V_swap = compute_analytical_swap_HW(x_grid, t_curr, start_date, a, sigma, B0_t_curr,...
    K, scheduleSwap, beta_vec, B0_acc_start)
% COMPUTE_ANALYTICAL_SWAP_HW Valuta il mark-to-market esatto dello swap 
% in ogni nodo spaziale x_grid al tempo t_curr, usando formule chiuse.

    payment_dates = scheduleSwap.payDates;
    accrual_start = scheduleSwap.accrualStart;
    yf_pay = scheduleSwap.yf_pay;
    notional_amortized = scheduleSwap.notionals;
    B0_T_pay = scheduleSwap.B_ois;
    F_forward = scheduleSwap.F_forward;

    % Inizializza il vettore dei valori dello swap per tutti i nodi spaziali
    V_swap = zeros(length(x_grid), 1);

    % Cicla su tutte le cedole
    for k = 1:length(payment_dates)
        T_p = payment_dates(k);
        T_s = accrual_start(k);

        % Considera solo i flussi che non sono ancora stati pagati
        if T_p > t_curr
            
            % 1. ZCB per attualizzare dalla data di pagamento al tempo corrente
            B_pay = compute_hw_zcb(x_grid, t_curr, T_p, a, sigma, B0_t_curr, B0_T_pay(k), start_date);

            % 2. FLUSSO FISSO (Sempre noto)
            cf_fixed = notional_amortized(k) * K * yf_pay(k);
            V_swap = V_swap - B_pay * cf_fixed;

            % 3. FLUSSO VARIABILE
            if T_s >= t_curr
                % L'accrual non è ancora iniziato: il FRA è stocastico. 
                % Usiamo l'equivalenza Multi-Curve per mantenere la volatilità!
                B_start = compute_hw_zcb(x_grid, t_curr, T_s, a, sigma, B0_t_curr, B0_acc_start(k), start_date);
                
                % Payoff stocastico
                cf_float_val = notional_amortized(k) * (beta_vec(k) * B_start - B_pay);
                V_swap = V_swap + cf_float_val;
            else
                % t_curr è dentro l'accrual period: il tasso è già stato fissato!
                % Il flusso è diventato una costante deterministica.
                cf_float_fixed = notional_amortized(k) * F_forward(k) * yf_pay(k);
                V_swap = V_swap + B_pay * cf_float_fixed;
            end
        end
    end
end