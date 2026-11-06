CREATE OR REPLACE FUNCTION confirm_reservation(
    p_reservation_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_status    VARCHAR(20);
    v_balance   NUMERIC(16,6);
    c_tolerance CONSTANT NUMERIC := 0.01;
BEGIN
    SELECT r.status
    INTO v_status
    FROM reservations AS r
    WHERE r.reservation_id = p_reservation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    IF v_status <> 'PENDING' THEN
        RAISE EXCEPTION 'Reservation must be PENDING.';
    END IF;

    v_balance := calculate_reservation_balance(
        p_reservation_id
    )::NUMERIC(16,6);

    IF ABS(v_balance) >= c_tolerance THEN
        RAISE EXCEPTION
            'Reservation % cannot be confirmed because its outstanding balance is not settled.',
            p_reservation_id;
    END IF;

    UPDATE reservations AS r
    SET status = 'CONFIRMED'
    WHERE r.reservation_id = p_reservation_id;
END;
$$;
