CREATE OR REPLACE FUNCTION get_reservation_summary(
    p_reservation_id BIGINT
)
RETURNS reservation_summary
LANGUAGE plpgsql
AS $$
DECLARE
    v_reservation reservation_summary;
BEGIN
    v_reservation := (
        SELECT ROW(
            r.reservation_id,
            g.full_name,
            p.property_name,
            r.total_amount,
            r.status
        )::reservation_summary
        FROM reservations AS r
        JOIN guests AS g
            ON r.guest_id = g.guest_id
        JOIN properties AS p
            ON r.property_id = p.property_id
        WHERE r.reservation_id = p_reservation_id
    );

    IF v_reservation IS NULL THEN
      RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    RETURN v_reservation;
END;
$$;