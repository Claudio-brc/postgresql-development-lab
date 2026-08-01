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