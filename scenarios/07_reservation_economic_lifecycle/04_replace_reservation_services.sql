CREATE OR REPLACE FUNCTION replace_reservation_services(
    p_reservation_id BIGINT,
    p_services       JSONB
)
RETURNS TABLE (
    reservation_id  BIGINT,
    reservation_total NUMERIC,
    amount_paid     NUMERIC,
    balance_due     NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status            VARCHAR(20);
    v_check_out_date    DATE;
    v_service           JSONB;
    v_service_id_value  NUMERIC;
    v_service_id        BIGINT;
    v_quantity_value    NUMERIC;
    v_quantity          INTEGER;
    v_unit_price        NUMERIC(14,6);
    v_is_active         BOOLEAN;
    v_seen_service_ids  BIGINT[] := ARRAY[]::BIGINT[];
    v_reservation_total NUMERIC(16,6);
    v_amount_paid       NUMERIC(16,6);
    v_balance_due       NUMERIC(16,6);
BEGIN
    SELECT r.status, r.check_out_date
    INTO v_status, v_check_out_date
    FROM reservations AS r
    WHERE r.reservation_id = p_reservation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE EXCEPTION 'Cancelled reservation % cannot be changed.', p_reservation_id;
    END IF;

    IF v_check_out_date < CURRENT_DATE THEN
        RAISE EXCEPTION 'Services cannot be changed after checkout.';
    END IF;

    IF p_services IS NOT NULL THEN
        IF jsonb_typeof(p_services) <> 'array' THEN
            RAISE EXCEPTION 'Expected a JSON array.';
        END IF;

        FOR v_service IN
            SELECT item.service_data
            FROM jsonb_array_elements(p_services) AS item(service_data)
        LOOP
            IF jsonb_typeof(v_service) <> 'object'
               OR NOT (v_service ? 'service_id')
               OR NOT (v_service ? 'quantity')
               OR jsonb_typeof(v_service -> 'service_id') <> 'number'
               OR jsonb_typeof(v_service -> 'quantity') <> 'number' THEN
                RAISE EXCEPTION
                    'Each service must be an object with numeric service_id and quantity.';
            END IF;

            v_service_id_value := (v_service ->> 'service_id')::NUMERIC;
            v_quantity_value := (v_service ->> 'quantity')::NUMERIC;

            IF v_service_id_value <= 0
               OR v_service_id_value <> TRUNC(v_service_id_value)
               OR v_service_id_value > 9223372036854775807 THEN
                RAISE EXCEPTION 'Service identifier must be a positive integer.';
            END IF;

            IF v_quantity_value <= 0
               OR v_quantity_value <> TRUNC(v_quantity_value)
               OR v_quantity_value > 2147483647 THEN
                RAISE EXCEPTION 'Service quantity must be a positive integer.';
            END IF;

            v_service_id := v_service_id_value::BIGINT;
            v_quantity := v_quantity_value::INTEGER;

            IF v_service_id = ANY(v_seen_service_ids) THEN
                RAISE EXCEPTION 'The service list contains repeated services.';
            END IF;
            v_seen_service_ids := array_append(v_seen_service_ids, v_service_id);

            SELECT s.price, s.is_active
            INTO v_unit_price, v_is_active
            FROM services AS s
            WHERE s.service_id = v_service_id
            FOR SHARE;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'Service % not found.', v_service_id;
            END IF;

            IF NOT v_is_active THEN
                RAISE EXCEPTION 'Service % is inactive.', v_service_id;
            END IF;
        END LOOP;

        DELETE FROM reservation_services AS rs
        WHERE rs.reservation_id = p_reservation_id;

        FOR v_service IN
            SELECT item.service_data
            FROM jsonb_array_elements(p_services) AS item(service_data)
        LOOP
            v_service_id := (v_service ->> 'service_id')::BIGINT;
            v_quantity := (v_service ->> 'quantity')::INTEGER;

            SELECT s.price::NUMERIC(14,6)
            INTO STRICT v_unit_price
            FROM services AS s
            WHERE s.service_id = v_service_id;

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

        v_reservation_total := calculate_reservation_total(
            p_reservation_id
        )::NUMERIC(16,6);

        UPDATE reservations AS r
        SET total_amount = v_reservation_total
        WHERE r.reservation_id = p_reservation_id;
    ELSE
        SELECT r.total_amount::NUMERIC(16,6)
        INTO v_reservation_total
        FROM reservations AS r
        WHERE r.reservation_id = p_reservation_id;
    END IF;

    v_amount_paid := calculate_reservation_amount_paid(
        p_reservation_id
    )::NUMERIC(16,6);
    v_balance_due := (v_reservation_total - v_amount_paid)::NUMERIC(16,6);

    RETURN QUERY
    SELECT
        p_reservation_id,
        v_reservation_total::NUMERIC(16,6),
        v_amount_paid::NUMERIC(16,6),
        v_balance_due::NUMERIC(16,6);
END;
$$;
