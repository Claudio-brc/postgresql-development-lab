CREATE OR REPLACE FUNCTION is_property_available(
    p_property_id    BIGINT,
    p_check_in_date  DATE,
    p_check_out_date DATE
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_conflict_exists BOOLEAN := FALSE;
    v_nights_quantity NUMERIC := 0;
    v_property_is_active BOOLEAN := NULL;
BEGIN
    v_nights_quantity := p_check_out_date - p_check_in_date;

    IF v_nights_quantity <= 0 THEN
        RAISE EXCEPTION 'dates are incorrect.';
    END IF;

    SELECT p.is_active
    INTO v_property_is_active
    FROM properties AS p
    WHERE p.property_id = p_property_id;

    IF v_property_is_active IS NULL THEN
        RAISE EXCEPTION 'Property % not found.', p_property_id;
    END IF;

    IF NOT v_property_is_active THEN
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
