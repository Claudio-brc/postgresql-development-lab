CREATE OR REPLACE FUNCTION add_services_to_reservation(
    p_reservation_id BIGINT,
    p_services       JSONB
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_service_id BIGINT;
    v_service    JSONB;
    v_unit_price NUMERIC;
    v_quantity   INTEGER;
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

    IF p_services IS NULL THEN
        RETURN;
    END IF;

    IF jsonb_typeof(p_services) <> 'array' THEN
        RAISE EXCEPTION
            'Expected a JSON array.';
    END IF;

    IF jsonb_array_length(p_services) = 0 THEN
        RETURN;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements(p_services) AS item(service_data)
        GROUP BY (service_data ->> 'service_id')::BIGINT
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION
            'The service list contains repeated services.';
    END IF;

    DELETE FROM reservation_services
    WHERE reservation_id = p_reservation_id;

    FOR v_service IN
        SELECT *
        FROM jsonb_array_elements(p_services)
    LOOP
        v_service_id := (v_service ->> 'service_id')::BIGINT;
        v_quantity := (v_service ->> 'quantity')::INTEGER;

        IF v_quantity IS NULL OR v_quantity <= 0 THEN
            RAISE EXCEPTION
                'Service quantity must be greater than zero.';
        END IF;

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
            v_quantity,
            v_unit_price
        );
    END LOOP;
END;
$$;
