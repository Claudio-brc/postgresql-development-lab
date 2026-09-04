CREATE OR REPLACE FUNCTION calculate_reservation_total(
    p_reservation_id BIGINT
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_property_id       BIGINT;
    v_check_in_date     DATE;
    v_check_out_date    DATE;
    v_accommodation     NUMERIC(16,6);
    v_services_subtotal NUMERIC(16,6);
BEGIN
    SELECT
        r.property_id,
        r.check_in_date,
        r.check_out_date
    INTO
        v_property_id,
        v_check_in_date,
        v_check_out_date
    FROM reservations AS r
    WHERE r.reservation_id = p_reservation_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    v_accommodation := calculate_booking_total(
        v_property_id,
        v_check_in_date,
        v_check_out_date
    )::NUMERIC(16,6);

    SELECT COALESCE(SUM(rs.quantity * rs.unit_price), 0)::NUMERIC(16,6)
    INTO v_services_subtotal
    FROM reservation_services AS rs
    WHERE rs.reservation_id = p_reservation_id;

    RETURN (v_accommodation + v_services_subtotal)::NUMERIC(16,6);
END;
$$;
