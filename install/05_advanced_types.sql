------------------------------------------------------------
-- PostgreSQL Development Lab
-- Scenario: 05_advanced_types
--
-- AUTO-GENERATED FILE
-- DO NOT EDIT MANUALLY
------------------------------------------------------------

------------------------------------------------------------
-- Source: 01_create_property.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION create_property(
    p_property property_request
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_property_id BIGINT;
BEGIN
    INSERT INTO properties (
        property_name,
        nightly_rate,
        is_active
    )
    VALUES (
        p_property.property_name,
        p_property.nightly_rate,
        p_property.is_active
    )
    RETURNING property_id
    INTO v_property_id;

    RETURN v_property_id;
END;
$$;


------------------------------------------------------------
-- Source: 02_get_reservation_summary.sql
------------------------------------------------------------

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


------------------------------------------------------------
-- Source: 03_add_services_to_reservation.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION add_services_to_reservation(
    p_reservation_id BIGINT,
    p_service_ids    BIGINT[]
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_unit_price NUMERIC;
    v_service_id BIGINT;
BEGIN

    -- ToDo:  what happend if i get repeated service id?
    IF NOT EXISTS (
        SELECT 1
        FROM reservations
        WHERE reservation_id = p_reservation_id
    ) THEN
        RAISE EXCEPTION
            'Reservation % not found.',
            p_reservation_id;
    END IF;

    DELETE FROM reservation_services
    WHERE reservation_id = p_reservation_id;

    IF p_service_ids IS NULL
       OR cardinality(p_service_ids) = 0 THEN
        RETURN;
    END IF;

    FOREACH v_service_id IN ARRAY p_service_ids
    LOOP
        SELECT price
        INTO v_unit_price
        FROM services
        WHERE service_id = v_service_id;

        IF v_unit_price IS NULL THEN
            RAISE EXCEPTION 'Service % not found.', v_service_id;
        END IF;

        INSERT INTO reservation_services (
            reservation_id,
            service_id,
            quantity,
            unit_price
        )
        VALUES (
            p_reservation_id,
            v_service_id,
            1,
            v_unit_price
        );
    END LOOP;
END;
$$;



