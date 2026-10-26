-- Apply after 007_increase_monetary_precision.sql.
-- Adds the reservation economic lifecycle without rewriting historical rows.

BEGIN;

-- Source: 01_calculate_reservation_total.sql

CREATE OR REPLACE FUNCTION calculate_reservation_total(
    p_reservation_id BIGINT
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_property_id       BIGINT;
    v_check_in_date     DATE;
    v_check_out_date    DATE;
    v_accommodation     NUMERIC(16,6);
    v_services_subtotal NUMERIC(16,6);
BEGIN
    SELECT
        r.property_id,
        r.check_in_date,
        r.check_out_date
    INTO
        v_property_id,
        v_check_in_date,
        v_check_out_date
    FROM reservations AS r
    WHERE r.reservation_id = p_reservation_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    v_accommodation := calculate_booking_total(
        v_property_id,
        v_check_in_date,
        v_check_out_date
    )::NUMERIC(16,6);

    SELECT COALESCE(SUM(rs.quantity * rs.unit_price), 0)::NUMERIC(16,6)
    INTO v_services_subtotal
    FROM reservation_services AS rs
    WHERE rs.reservation_id = p_reservation_id;

    RETURN (v_accommodation + v_services_subtotal)::NUMERIC(16,6);
END;
$$;

-- Source: 02_calculate_reservation_amount_paid.sql

CREATE OR REPLACE FUNCTION calculate_reservation_amount_paid(
    p_reservation_id BIGINT
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_amount_paid NUMERIC(16,6);
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM reservations AS r
        WHERE r.reservation_id = p_reservation_id
    ) THEN
        RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    SELECT COALESCE(SUM(p.payment_amount), 0)::NUMERIC(16,6)
    INTO v_amount_paid
    FROM payments AS p
    WHERE p.reservation_id = p_reservation_id
      AND p.status = 'PAID';

    RETURN v_amount_paid::NUMERIC(16,6);
END;
$$;

-- Source: 03_calculate_reservation_balance.sql

CREATE OR REPLACE FUNCTION calculate_reservation_balance(
    p_reservation_id BIGINT
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_reservation_total NUMERIC(16,6);
    v_amount_paid       NUMERIC(16,6);
BEGIN
    SELECT r.total_amount
    INTO v_reservation_total
    FROM reservations AS r
    WHERE r.reservation_id = p_reservation_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    v_amount_paid := calculate_reservation_amount_paid(
        p_reservation_id
    )::NUMERIC(16,6);

    RETURN (v_reservation_total - v_amount_paid)::NUMERIC(16,6);
END;
$$;

-- Source: 04_replace_reservation_services.sql

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

-- Source: 05_remove_obsolete_service_wrappers.sql

-- Scenarios 05 and 06 retain these names to show the evolution from ARRAY to
-- JSONB input. In the final API, service replacement has one canonical entry
-- point with explicit collection semantics and an economic-state result.
DROP FUNCTION IF EXISTS add_services_to_reservation(BIGINT, BIGINT[]);
DROP FUNCTION IF EXISTS add_services_to_reservation(BIGINT, JSONB);

-- Source: 06_initialize_reservation.sql

CREATE OR REPLACE FUNCTION initialize_reservation(
    p_guest_id          BIGINT,
    p_property_id       BIGINT,
    p_check_in          DATE,
    p_check_out         DATE,
    p_created_by_user_id BIGINT,
    p_services          JSONB
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_amount   NUMERIC(16,6);
    v_reservation_id BIGINT;
    v_is_available   BOOLEAN;
BEGIN
    PERFORM validate_booking_dates(p_check_in, p_check_out);

    v_is_available := is_property_available(
        p_property_id,
        p_check_in,
        p_check_out
    );

    IF NOT v_is_available THEN
        RAISE EXCEPTION 'Property is not available for the selected dates.';
    END IF;

    PERFORM can_guest_book(p_guest_id);

    v_total_amount := calculate_booking_total(
        p_property_id,
        p_check_in,
        p_check_out
    )::NUMERIC(16,6);

    INSERT INTO reservations (
        guest_id,
        property_id,
        check_in_date,
        check_out_date,
        total_amount,
        status,
        created_by_user_id
    )
    VALUES (
        p_guest_id,
        p_property_id,
        p_check_in,
        p_check_out,
        v_total_amount,
        'PENDING',
        p_created_by_user_id
    )
    RETURNING reservation_id INTO v_reservation_id;

    IF p_services IS NOT NULL THEN
        PERFORM replace_reservation_services(v_reservation_id, p_services);
    END IF;

    RETURN v_reservation_id;
END;
$$;

CREATE OR REPLACE FUNCTION initialize_reservation(
    p_guest_id          BIGINT,
    p_property_id       BIGINT,
    p_check_in          DATE,
    p_check_out         DATE,
    p_created_by_user_id BIGINT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN initialize_reservation(
        p_guest_id,
        p_property_id,
        p_check_in,
        p_check_out,
        p_created_by_user_id,
        NULL::JSONB
    );
END;
$$;

-- Source: 07_process_reservation_payment.sql

CREATE OR REPLACE FUNCTION process_reservation_payment(
    p_reservation_id BIGINT,
    p_payment_amount NUMERIC,
    p_payment_method VARCHAR(30)
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_status         VARCHAR(20);
    v_balance_due    NUMERIC(16,6);
    v_payment_amount NUMERIC(16,6);
    v_payment_id     BIGINT;
BEGIN
    SELECT r.status
    INTO v_status
    FROM reservations AS r
    WHERE r.reservation_id = p_reservation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE EXCEPTION 'Cancelled reservation % cannot receive payments.', p_reservation_id;
    END IF;

    IF COALESCE(p_payment_amount, 0) <= 0 THEN
        RAISE EXCEPTION 'Payment amount must be greater than zero.';
    END IF;

    IF NULLIF(BTRIM(p_payment_method), '') IS NULL THEN
        RAISE EXCEPTION 'Payment method cannot be blank.';
    END IF;

    v_payment_amount := p_payment_amount::NUMERIC(16,6);
    v_balance_due := calculate_reservation_balance(
        p_reservation_id
    )::NUMERIC(16,6);

    IF v_balance_due <= 0 THEN
        RAISE EXCEPTION 'Reservation % has no positive balance due.', p_reservation_id;
    END IF;

    -- The tolerance decides settlement only. Both operands retain six-decimal
    -- precision and are never rounded to cents before this comparison.
    IF ABS(v_balance_due - v_payment_amount) >= 0.01 THEN
        RAISE EXCEPTION 'Payment amount does not match the outstanding balance.';
    END IF;

    INSERT INTO payments (
        reservation_id,
        payment_amount,
        payment_method,
        status,
        payment_date
    )
    VALUES (
        p_reservation_id,
        v_payment_amount,
        BTRIM(p_payment_method),
        'PAID',
        CURRENT_TIMESTAMP
    )
    RETURNING payment_id INTO v_payment_id;

    IF v_status = 'PENDING' THEN
        PERFORM confirm_reservation(p_reservation_id);
    END IF;

    RETURN v_payment_id;
END;
$$;

-- Source: 08_create_reservation.sql

-- The eight-argument form is the canonical implementation. Payment is absent
-- only when both payment fields are NULL; incomplete payment input is rejected.
CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id          BIGINT,
    p_property_id       BIGINT,
    p_check_in          DATE,
    p_check_out         DATE,
    p_payment_amount    NUMERIC,
    p_payment_method    VARCHAR(30),
    p_created_by_user_id BIGINT,
    p_services          JSONB
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_reservation_id BIGINT;
BEGIN
    v_reservation_id := initialize_reservation(
        p_guest_id,
        p_property_id,
        p_check_in,
        p_check_out,
        p_created_by_user_id,
        p_services
    );

    IF p_payment_amount IS NULL AND p_payment_method IS NULL THEN
        RETURN v_reservation_id;
    END IF;

    IF p_payment_amount IS NULL OR p_payment_method IS NULL THEN
        RAISE EXCEPTION 'Payment amount and payment method must be supplied together.';
    END IF;

    PERFORM process_reservation_payment(
        v_reservation_id,
        p_payment_amount,
        p_payment_method
    );

    RETURN v_reservation_id;
END;
$$;

CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id          BIGINT,
    p_property_id       BIGINT,
    p_check_in          DATE,
    p_check_out         DATE,
    p_payment_amount    NUMERIC,
    p_payment_method    VARCHAR(30),
    p_created_by_user_id BIGINT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id,
        p_property_id,
        p_check_in,
        p_check_out,
        p_payment_amount,
        p_payment_method,
        p_created_by_user_id,
        NULL::JSONB
    );
END;
$$;

CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id          BIGINT,
    p_property_id       BIGINT,
    p_check_in          DATE,
    p_check_out         DATE,
    p_created_by_user_id BIGINT,
    p_services          JSONB
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id,
        p_property_id,
        p_check_in,
        p_check_out,
        NULL::NUMERIC,
        NULL::VARCHAR(30),
        p_created_by_user_id,
        p_services
    );
END;
$$;

CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id          BIGINT,
    p_property_id       BIGINT,
    p_check_in          DATE,
    p_check_out         DATE,
    p_created_by_user_id BIGINT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id,
        p_property_id,
        p_check_in,
        p_check_out,
        p_created_by_user_id,
        NULL::JSONB
    );
END;
$$;

-- The former name described workflow rather than domain intent. Scenario 02
-- remains unchanged as history; only the final installed API removes it.
DROP FUNCTION IF EXISTS process_booking(
    BIGINT, BIGINT, DATE, DATE, NUMERIC, VARCHAR, BIGINT, JSONB
);
DROP FUNCTION IF EXISTS process_booking(
    BIGINT, BIGINT, DATE, DATE, NUMERIC, VARCHAR, BIGINT
);

COMMIT;

