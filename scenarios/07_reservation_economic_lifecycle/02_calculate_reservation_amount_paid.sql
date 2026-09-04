CREATE OR REPLACE FUNCTION calculate_reservation_amount_paid(
    p_reservation_id BIGINT
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_amount_paid NUMERIC(16,6);
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM reservations AS r
        WHERE r.reservation_id = p_reservation_id
    ) THEN
        RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    SELECT COALESCE(SUM(p.payment_amount), 0)::NUMERIC(16,6)
    INTO v_amount_paid
    FROM payments AS p
    WHERE p.reservation_id = p_reservation_id
      AND p.status = 'PAID';

    RETURN v_amount_paid::NUMERIC(16,6);
END;
$$;
