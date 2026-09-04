CREATE OR REPLACE FUNCTION process_reservation_payment(
    p_reservation_id BIGINT,
    p_payment_amount NUMERIC,
    p_payment_method VARCHAR(30)
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_status         VARCHAR(20);
    v_balance_due    NUMERIC(16,6);
    v_payment_amount NUMERIC(16,6);
    v_payment_id     BIGINT;
BEGIN
    SELECT r.status
    INTO v_status
    FROM reservations AS r
    WHERE r.reservation_id = p_reservation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE EXCEPTION 'Cancelled reservation % cannot receive payments.', p_reservation_id;
    END IF;

    IF COALESCE(p_payment_amount, 0) <= 0 THEN
        RAISE EXCEPTION 'Payment amount must be greater than zero.';
    END IF;

    IF NULLIF(BTRIM(p_payment_method), '') IS NULL THEN
        RAISE EXCEPTION 'Payment method cannot be blank.';
    END IF;

    v_payment_amount := p_payment_amount::NUMERIC(16,6);
    v_balance_due := calculate_reservation_balance(
        p_reservation_id
    )::NUMERIC(16,6);

    IF v_balance_due <= 0 THEN
        RAISE EXCEPTION 'Reservation % has no positive balance due.', p_reservation_id;
    END IF;

    -- The tolerance decides settlement only. Both operands retain six-decimal
    -- precision and are never rounded to cents before this comparison.
    IF ABS(v_balance_due - v_payment_amount) >= 0.01 THEN
        RAISE EXCEPTION 'Payment amount does not match the outstanding balance.';
    END IF;

    INSERT INTO payments (
        reservation_id,
        payment_amount,
        payment_method,
        status,
        payment_date
    )
    VALUES (
        p_reservation_id,
        v_payment_amount,
        BTRIM(p_payment_method),
        'PAID',
        CURRENT_TIMESTAMP
    )
    RETURNING payment_id INTO v_payment_id;

    IF v_status = 'PENDING' THEN
        PERFORM confirm_reservation(p_reservation_id);
    END IF;

    RETURN v_payment_id;
END;
$$;
