-- The four-argument form is the canonical implementation. The historical
-- three-argument form delegates with the compatibility occupancy of one.
CREATE OR REPLACE FUNCTION is_property_available(
    p_property_id    BIGINT,
    p_check_in_date  DATE,
    p_check_out_date DATE,
    p_guests_count   INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_conflict_exists   BOOLEAN := FALSE;
    v_nights_quantity  INTEGER;
    v_property_is_active BOOLEAN;
    v_max_guests       INTEGER;
BEGIN
    IF p_guests_count IS NULL OR p_guests_count <= 0 THEN
        RAISE EXCEPTION 'Guest count must be greater than zero.';
    END IF;

    v_nights_quantity := p_check_out_date - p_check_in_date;

    IF v_nights_quantity <= 0 THEN
        RAISE EXCEPTION 'dates are incorrect.';
    END IF;

    SELECT p.is_active, p.max_guests
    INTO v_property_is_active, v_max_guests
    FROM properties AS p
    WHERE p.property_id = p_property_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Property % not found.', p_property_id;
    END IF;

    IF NOT v_property_is_active OR p_guests_count > v_max_guests THEN
        RETURN FALSE;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM reservations AS r
        WHERE r.check_in_date < p_check_out_date
          AND r.check_out_date > p_check_in_date
          AND r.property_id = p_property_id
          AND r.status IN ('PENDING', 'CONFIRMED')
    )
    INTO v_conflict_exists;

    RETURN NOT v_conflict_exists;
END;
$$;

CREATE OR REPLACE FUNCTION is_property_available(
    p_property_id    BIGINT,
    p_check_in_date  DATE,
    p_check_out_date DATE
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN is_property_available(
        p_property_id,
        p_check_in_date,
        p_check_out_date,
        1
    );
END;
$$;
