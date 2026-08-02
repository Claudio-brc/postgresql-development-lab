------------------------------------------------------------
-- PostgreSQL Development Lab
-- Scenario: 01_plpgsql_fundamentals
--
-- AUTO-GENERATED FILE
-- DO NOT EDIT MANUALLY
------------------------------------------------------------

------------------------------------------------------------
-- Source: 01_calculate_stay_cost.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION calculate_stay_cost(
    p_property_id    BIGINT,
    p_check_in_date  DATE,
    p_check_out_date DATE
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_cost       NUMERIC := 0;
    v_nights_quantity  NUMERIC := 0;
BEGIN
    --exception error de fechas
    v_nights_quantity := p_check_out_date - p_check_in_date;

    IF v_nights_quantity <= 0 THEN
        RAISE EXCEPTION 'dates are incorrect.';
    END IF;

    SELECT p.nightly_rate
    INTO v_total_cost
    FROM properties AS p
    WHERE p.property_id = p_property_id;

    IF v_total_cost IS NULL THEN
        RAISE EXCEPTION 'Property % not found.', p_property_id;
    END IF;

    RETURN v_nights_quantity * v_total_cost;
END;
$$;


------------------------------------------------------------
-- Source: 02_is_property_available.sql
------------------------------------------------------------

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



------------------------------------------------------------
-- Source: 03_show_guest_reservations.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION show_guest_reservations(
    p_guest_id BIGINT
)
RETURNS TABLE (
    reservation_id BIGINT,
    property_name  VARCHAR(150),
    check_in       DATE,
    check_out      DATE,
    status         TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_guest_exists BIGINT;
    rec            RECORD;
BEGIN
    SELECT g.guest_id
    INTO v_guest_exists
    FROM guests AS g
    WHERE g.guest_id = p_guest_id;

    IF v_guest_exists IS NULL THEN
        RAISE EXCEPTION 'Guest % not found.', p_guest_id;
    END IF;

    FOR rec IN
        SELECT
            r.reservation_id,
            p.property_name,
            r.check_in_date,
            r.check_out_date,
            r.status
        FROM reservations AS r
        INNER JOIN properties AS p
            ON p.property_id = r.property_id
        WHERE r.guest_id = p_guest_id
    LOOP
        reservation_id := rec.reservation_id;
        property_name  := rec.property_name;
        check_in       := rec.check_in_date;
        check_out      := rec.check_out_date;
        status         := rec.status;

        RETURN NEXT;
    END LOOP;
END;
$$;


------------------------------------------------------------
-- Source: 04_show_guest_reservations_return_query.sql
------------------------------------------------------------

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



