CREATE OR REPLACE FUNCTION calculate_reservation_potential_value_in_base_currency(
    p_reservation_id BIGINT
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_value NUMERIC(16,6);
BEGIN
    SELECT (r.total_amount * r.exchange_rate)::NUMERIC(16,6)
    INTO v_value
    FROM reservations AS r
    WHERE r.reservation_id = p_reservation_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    RETURN v_value;
END;
$$;

CREATE OR REPLACE FUNCTION calculate_reservation_collected_value_in_base_currency(
    p_reservation_id BIGINT
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_value NUMERIC(16,6);
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM reservations AS r
        WHERE r.reservation_id = p_reservation_id
    ) THEN
        RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    SELECT COALESCE(SUM(p.payment_amount * p.exchange_rate), 0)::NUMERIC(16,6)
    INTO v_value
    FROM payments AS p
    WHERE p.reservation_id = p_reservation_id
      AND p.status = 'PAID';

    RETURN v_value;
END;
$$;
