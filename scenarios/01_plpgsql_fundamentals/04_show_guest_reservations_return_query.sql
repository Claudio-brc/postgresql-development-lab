CREATE OR REPLACE FUNCTION show_guest_reservations_return_query(
    p_guest_id BIGINT
)
RETURNS TABLE (
    reservation_id BIGINT,
    property_name  VARCHAR(150),
    check_in       DATE,
    check_out      DATE,
    status         VARCHAR(20)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_guest_exists BIGINT;
BEGIN
    SELECT g.guest_id
    INTO v_guest_exists
    FROM guests AS g
    WHERE g.guest_id = p_guest_id;

    IF v_guest_exists IS NULL THEN
        RAISE EXCEPTION 'Guest % not found.', p_guest_id;
    END IF;

    RETURN QUERY
        SELECT
            r.reservation_id,
            p.property_name,
            r.check_in_date,
            r.check_out_date,
            r.status
        FROM reservations AS r
        INNER JOIN properties AS p
            ON p.property_id = r.property_id
        WHERE r.guest_id = p_guest_id;
END;
$$;