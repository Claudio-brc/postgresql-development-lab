CREATE OR REPLACE FUNCTION calculate_reservation_balance(
    p_reservation_id BIGINT
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_reservation_total NUMERIC(16,6);
    v_amount_paid       NUMERIC(16,6);
BEGIN
    SELECT r.total_amount
    INTO v_reservation_total
    FROM reservations AS r
    WHERE r.reservation_id = p_reservation_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    v_amount_paid := calculate_reservation_amount_paid(
        p_reservation_id
    )::NUMERIC(16,6);

    RETURN (v_reservation_total - v_amount_paid)::NUMERIC(16,6);
END;
$$;
