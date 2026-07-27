CREATE OR REPLACE FUNCTION can_guest_book(
    p_guest_id BIGINT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_guest_exists       BIGINT;
    v_reservation_count  INT;
    v_max_pending        INTEGER;
BEGIN
    SELECT g.guest_id
    INTO v_guest_exists
    FROM guests AS g
    WHERE g.guest_id = p_guest_id;

    IF v_guest_exists IS NULL THEN
        RAISE EXCEPTION 'Guest not found.';
    END IF;

    SELECT COUNT(*)
    INTO v_reservation_count
    FROM reservations AS r
    WHERE r.guest_id = p_guest_id
      AND r.status = 'PENDING';

    v_max_pending := get_setting('max_pending_reservations')::INTEGER;

    IF v_max_pending <= v_reservation_count THEN
        RAISE EXCEPTION 'Guest has reached the maximum number of pending reservations.';
    END IF;

    RETURN TRUE;
END;
$$;