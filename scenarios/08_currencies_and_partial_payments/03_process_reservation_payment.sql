CREATE OR REPLACE FUNCTION process_reservation_payment(
    p_reservation_id BIGINT,
    p_payment_amount NUMERIC,
    p_payment_method VARCHAR(30),
    p_exchange_rate  NUMERIC
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_status          VARCHAR(20);
    v_currency_code   VARCHAR(3);
    v_balance_due     NUMERIC(16,6);
    v_new_balance     NUMERIC(16,6);
    v_payment_amount  NUMERIC(16,6);
    v_payment_id      BIGINT;
    c_tolerance       CONSTANT NUMERIC := 0.01;
BEGIN
    SELECT r.status, r.currency_code
    INTO v_status, v_currency_code
    FROM reservations AS r
    WHERE r.reservation_id = p_reservation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE EXCEPTION 'Cancelled reservation % cannot receive payments.', p_reservation_id;
    END IF;

    IF p_payment_amount IS NULL OR p_payment_amount <= 0 THEN
        RAISE EXCEPTION 'Payment amount must be greater than zero.';
    END IF;

    IF NULLIF(BTRIM(p_payment_method), '') IS NULL THEN
        RAISE EXCEPTION 'Payment method cannot be blank.';
    END IF;

    PERFORM validate_currency_exchange_rate(v_currency_code, p_exchange_rate);

    v_payment_amount := p_payment_amount::NUMERIC(16,6);
    v_balance_due := calculate_reservation_balance(
        p_reservation_id
    )::NUMERIC(16,6);

    IF v_balance_due <= 0 THEN
        RAISE EXCEPTION 'Reservation % has no positive balance due.', p_reservation_id;
    END IF;

    -- A difference smaller than the existing tolerance is accepted as final
    -- settlement. Partial payments below the balance are always valid.
    IF v_payment_amount - v_balance_due >= c_tolerance THEN
        RAISE EXCEPTION 'Payment amount exceeds the outstanding balance.';
    END IF;

    INSERT INTO payments (
        reservation_id,
        payment_amount,
        exchange_rate,
        payment_method,
        status,
        payment_date
    )
    VALUES (
        p_reservation_id,
        v_payment_amount,
        p_exchange_rate::NUMERIC(20,10),
        BTRIM(p_payment_method),
        'PAID',
        CURRENT_TIMESTAMP
    )
    RETURNING payment_id INTO v_payment_id;

    v_new_balance := (v_balance_due - v_payment_amount)::NUMERIC(16,6);

    IF ABS(v_new_balance) < c_tolerance AND v_status = 'PENDING' THEN
        PERFORM confirm_reservation(p_reservation_id);
    END IF;

    RETURN v_payment_id;
END;
$$;

-- Compatibility is unambiguous only for base-currency reservations, whose
-- rate is necessarily 1. Foreign-currency payments must supply a fresh rate.
CREATE OR REPLACE FUNCTION process_reservation_payment(
    p_reservation_id BIGINT,
    p_payment_amount NUMERIC,
    p_payment_method VARCHAR(30)
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_currency_code VARCHAR(3);
BEGIN
    SELECT currency_code INTO v_currency_code
    FROM reservations
    WHERE reservation_id = p_reservation_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    IF v_currency_code <> get_setting('base_currency_code') THEN
        RAISE EXCEPTION 'An exchange rate is required for a foreign-currency payment.';
    END IF;

    RETURN process_reservation_payment(
        p_reservation_id, p_payment_amount, p_payment_method, 1::NUMERIC
    );
END;
$$;
