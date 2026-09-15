------------------------------------------------------------
-- PostgreSQL Development Lab
-- Scenario: 08_currencies_and_partial_payments
--
-- AUTO-GENERATED FILE
-- DO NOT EDIT MANUALLY
------------------------------------------------------------

------------------------------------------------------------
-- Source: 01_base_currency_reporting.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION calculate_reservation_potential_value_in_base_currency(
    p_reservation_id BIGINT
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_value NUMERIC(16,6);
BEGIN
    SELECT (r.total_amount * r.exchange_rate)::NUMERIC(16,6)
    INTO v_value
    FROM reservations AS r
    WHERE r.reservation_id = p_reservation_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    RETURN v_value;
END;
$$;

CREATE OR REPLACE FUNCTION calculate_reservation_collected_value_in_base_currency(
    p_reservation_id BIGINT
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_value NUMERIC(16,6);
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM reservations AS r
        WHERE r.reservation_id = p_reservation_id
    ) THEN
        RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    SELECT COALESCE(SUM(p.payment_amount * p.exchange_rate), 0)::NUMERIC(16,6)
    INTO v_value
    FROM payments AS p
    WHERE p.reservation_id = p_reservation_id
      AND p.status = 'PAID';

    RETURN v_value;
END;
$$;



------------------------------------------------------------
-- Source: 02_initialize_reservation.sql
------------------------------------------------------------

-- The eight-argument form owns reservation creation. Compatibility overloads
-- delegate using the configured base currency at rate 1.
CREATE OR REPLACE FUNCTION initialize_reservation(
    p_guest_id           BIGINT,
    p_property_id        BIGINT,
    p_check_in           DATE,
    p_check_out          DATE,
    p_created_by_user_id BIGINT,
    p_services           JSONB,
    p_currency_code      VARCHAR(3),
    p_exchange_rate      NUMERIC
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_amount   NUMERIC(16,6);
    v_reservation_id BIGINT;
    v_is_available   BOOLEAN;
    v_currency_code  VARCHAR(3);
BEGIN
    v_currency_code := validate_currency_exchange_rate(
        p_currency_code,
        p_exchange_rate
    );

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
        created_by_user_id,
        currency_code,
        exchange_rate
    )
    VALUES (
        p_guest_id,
        p_property_id,
        p_check_in,
        p_check_out,
        v_total_amount,
        'PENDING',
        p_created_by_user_id,
        v_currency_code,
        p_exchange_rate::NUMERIC(20,10)
    )
    RETURNING reservation_id INTO v_reservation_id;

    IF p_services IS NOT NULL THEN
        PERFORM replace_reservation_services(v_reservation_id, p_services);
    END IF;

    RETURN v_reservation_id;
END;
$$;

CREATE OR REPLACE FUNCTION initialize_reservation(
    p_guest_id           BIGINT,
    p_property_id        BIGINT,
    p_check_in           DATE,
    p_check_out          DATE,
    p_created_by_user_id BIGINT,
    p_currency_code      VARCHAR(3),
    p_exchange_rate      NUMERIC
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN initialize_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out,
        p_created_by_user_id, NULL::JSONB, p_currency_code, p_exchange_rate
    );
END;
$$;

CREATE OR REPLACE FUNCTION initialize_reservation(
    p_guest_id           BIGINT,
    p_property_id        BIGINT,
    p_check_in           DATE,
    p_check_out          DATE,
    p_created_by_user_id BIGINT,
    p_services           JSONB
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN initialize_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out,
        p_created_by_user_id, p_services,
        get_setting('base_currency_code')::VARCHAR(3), 1::NUMERIC
    );
END;
$$;

CREATE OR REPLACE FUNCTION initialize_reservation(
    p_guest_id           BIGINT,
    p_property_id        BIGINT,
    p_check_in           DATE,
    p_check_out          DATE,
    p_created_by_user_id BIGINT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN initialize_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out,
        p_created_by_user_id, NULL::JSONB
    );
END;
$$;



------------------------------------------------------------
-- Source: 03_process_reservation_payment.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION process_reservation_payment(
    p_reservation_id BIGINT,
    p_payment_amount NUMERIC,
    p_payment_method VARCHAR(30),
    p_exchange_rate  NUMERIC
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_status          VARCHAR(20);
    v_currency_code   VARCHAR(3);
    v_balance_due     NUMERIC(16,6);
    v_new_balance     NUMERIC(16,6);
    v_payment_amount  NUMERIC(16,6);
    v_payment_id      BIGINT;
    c_tolerance       CONSTANT NUMERIC := 0.01;
BEGIN
    SELECT r.status, r.currency_code
    INTO v_status, v_currency_code
    FROM reservations AS r
    WHERE r.reservation_id = p_reservation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE EXCEPTION 'Cancelled reservation % cannot receive payments.', p_reservation_id;
    END IF;

    IF p_payment_amount IS NULL OR p_payment_amount <= 0 THEN
        RAISE EXCEPTION 'Payment amount must be greater than zero.';
    END IF;

    IF NULLIF(BTRIM(p_payment_method), '') IS NULL THEN
        RAISE EXCEPTION 'Payment method cannot be blank.';
    END IF;

    PERFORM validate_currency_exchange_rate(v_currency_code, p_exchange_rate);

    v_payment_amount := p_payment_amount::NUMERIC(16,6);
    v_balance_due := calculate_reservation_balance(
        p_reservation_id
    )::NUMERIC(16,6);

    IF v_balance_due <= 0 THEN
        RAISE EXCEPTION 'Reservation % has no positive balance due.', p_reservation_id;
    END IF;

    -- A difference smaller than the existing tolerance is accepted as final
    -- settlement. Partial payments below the balance are always valid.
    IF v_payment_amount - v_balance_due >= c_tolerance THEN
        RAISE EXCEPTION 'Payment amount exceeds the outstanding balance.';
    END IF;

    INSERT INTO payments (
        reservation_id,
        payment_amount,
        exchange_rate,
        payment_method,
        status,
        payment_date
    )
    VALUES (
        p_reservation_id,
        v_payment_amount,
        p_exchange_rate::NUMERIC(20,10),
        BTRIM(p_payment_method),
        'PAID',
        CURRENT_TIMESTAMP
    )
    RETURNING payment_id INTO v_payment_id;

    v_new_balance := (v_balance_due - v_payment_amount)::NUMERIC(16,6);

    IF ABS(v_new_balance) < c_tolerance AND v_status = 'PENDING' THEN
        PERFORM confirm_reservation(p_reservation_id);
    END IF;

    RETURN v_payment_id;
END;
$$;

-- Compatibility is unambiguous only for base-currency reservations, whose
-- rate is necessarily 1. Foreign-currency payments must supply a fresh rate.
CREATE OR REPLACE FUNCTION process_reservation_payment(
    p_reservation_id BIGINT,
    p_payment_amount NUMERIC,
    p_payment_method VARCHAR(30)
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_currency_code VARCHAR(3);
BEGIN
    SELECT currency_code INTO v_currency_code
    FROM reservations
    WHERE reservation_id = p_reservation_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    IF v_currency_code <> get_setting('base_currency_code') THEN
        RAISE EXCEPTION 'An exchange rate is required for a foreign-currency payment.';
    END IF;

    RETURN process_reservation_payment(
        p_reservation_id, p_payment_amount, p_payment_method, 1::NUMERIC
    );
END;
$$;



------------------------------------------------------------
-- Source: 04_create_reservation.sql
------------------------------------------------------------

-- Canonical creation accepts independent reservation-time and payment-time
-- rate snapshots. All overloads delegate here or to another delegating form.
CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id                  BIGINT,
    p_property_id               BIGINT,
    p_check_in                  DATE,
    p_check_out                 DATE,
    p_payment_amount            NUMERIC,
    p_payment_method            VARCHAR(30),
    p_created_by_user_id        BIGINT,
    p_services                  JSONB,
    p_currency_code             VARCHAR(3),
    p_reservation_exchange_rate NUMERIC,
    p_payment_exchange_rate     NUMERIC
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_reservation_id BIGINT;
BEGIN
    v_reservation_id := initialize_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out,
        p_created_by_user_id, p_services, p_currency_code,
        p_reservation_exchange_rate
    );

    IF p_payment_amount IS NULL
       AND p_payment_method IS NULL
       AND p_payment_exchange_rate IS NULL THEN
        RETURN v_reservation_id;
    END IF;

    IF p_payment_amount IS NULL
       OR p_payment_method IS NULL
       OR p_payment_exchange_rate IS NULL THEN
        RAISE EXCEPTION 'Payment amount, payment method, and payment exchange rate must be supplied together.';
    END IF;

    PERFORM process_reservation_payment(
        v_reservation_id,
        p_payment_amount,
        p_payment_method,
        p_payment_exchange_rate
    );

    RETURN v_reservation_id;
END;
$$;

-- Explicit-currency paid creation without services.
CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id                  BIGINT,
    p_property_id               BIGINT,
    p_check_in                  DATE,
    p_check_out                 DATE,
    p_payment_amount            NUMERIC,
    p_payment_method            VARCHAR(30),
    p_created_by_user_id        BIGINT,
    p_currency_code             VARCHAR(3),
    p_reservation_exchange_rate NUMERIC,
    p_payment_exchange_rate     NUMERIC
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out,
        p_payment_amount, p_payment_method, p_created_by_user_id,
        NULL::JSONB, p_currency_code, p_reservation_exchange_rate,
        p_payment_exchange_rate
    );
END;
$$;

-- Explicit-currency unpaid creation, with or without services.
CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id                  BIGINT,
    p_property_id               BIGINT,
    p_check_in                  DATE,
    p_check_out                 DATE,
    p_created_by_user_id        BIGINT,
    p_services                  JSONB,
    p_currency_code             VARCHAR(3),
    p_reservation_exchange_rate NUMERIC
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out,
        NULL::NUMERIC, NULL::VARCHAR(30), p_created_by_user_id,
        p_services, p_currency_code, p_reservation_exchange_rate, NULL::NUMERIC
    );
END;
$$;

CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id                  BIGINT,
    p_property_id               BIGINT,
    p_check_in                  DATE,
    p_check_out                 DATE,
    p_created_by_user_id        BIGINT,
    p_currency_code             VARCHAR(3),
    p_reservation_exchange_rate NUMERIC
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out,
        p_created_by_user_id, NULL::JSONB, p_currency_code,
        p_reservation_exchange_rate
    );
END;
$$;

-- Existing call shapes remain base-currency convenience overloads.
CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id           BIGINT,
    p_property_id        BIGINT,
    p_check_in           DATE,
    p_check_out          DATE,
    p_payment_amount     NUMERIC,
    p_payment_method     VARCHAR(30),
    p_created_by_user_id BIGINT,
    p_services           JSONB
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out,
        p_payment_amount, p_payment_method, p_created_by_user_id, p_services,
        get_setting('base_currency_code')::VARCHAR(3), 1::NUMERIC,
        CASE WHEN p_payment_amount IS NULL AND p_payment_method IS NULL
             THEN NULL::NUMERIC ELSE 1::NUMERIC END
    );
END;
$$;

CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id           BIGINT,
    p_property_id        BIGINT,
    p_check_in           DATE,
    p_check_out          DATE,
    p_payment_amount     NUMERIC,
    p_payment_method     VARCHAR(30),
    p_created_by_user_id BIGINT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out,
        p_payment_amount, p_payment_method, p_created_by_user_id, NULL::JSONB
    );
END;
$$;

CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id           BIGINT,
    p_property_id        BIGINT,
    p_check_in           DATE,
    p_check_out          DATE,
    p_created_by_user_id BIGINT,
    p_services           JSONB
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out,
        p_created_by_user_id, p_services,
        get_setting('base_currency_code')::VARCHAR(3), 1::NUMERIC
    );
END;
$$;

CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id           BIGINT,
    p_property_id        BIGINT,
    p_check_in           DATE,
    p_check_out          DATE,
    p_created_by_user_id BIGINT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out,
        p_created_by_user_id, NULL::JSONB
    );
END;
$$;




