CREATE OR REPLACE FUNCTION cancel_reservation(
    p_reservation_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_status         VARCHAR(20);
    v_check_out_date DATE;
BEGIN
    SELECT r.status, r.check_out_date
    INTO v_status, v_check_out_date
    FROM reservations AS r
    WHERE r.reservation_id = p_reservation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE EXCEPTION 'Reservation is already cancelled.';
    END IF;

    IF v_status NOT IN ('PENDING', 'CONFIRMED') THEN
        RAISE EXCEPTION 'Reservation must be PENDING or CONFIRMED to be cancelled.';
    END IF;

    IF v_status = 'CONFIRMED' AND v_check_out_date < CURRENT_DATE THEN
        RAISE EXCEPTION
            'Confirmed reservation % cannot be cancelled because its check-out date % is in the past.',
            p_reservation_id,
            v_check_out_date;
    END IF;

    UPDATE reservations AS r
    SET status = 'CANCELLED'
    WHERE r.reservation_id = p_reservation_id;
END;
$$;
