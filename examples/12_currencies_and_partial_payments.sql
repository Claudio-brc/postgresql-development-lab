-- Run after installing the consolidated Development Lab schema.
-- All generated rows are rolled back.

BEGIN;

DO $$
DECLARE
    v_user_id        BIGINT;
    v_guest_id       BIGINT;
    v_property_id    BIGINT;
    v_reservation_id BIGINT;
    v_direct_reservation_id BIGINT;
    v_literal_reservation_id BIGINT;
    v_payment_id     BIGINT;
    v_rejected       BOOLEAN;
    v_error_message  TEXT;
BEGIN
    IF get_setting('base_currency_code') <> 'ARS' THEN
        RAISE EXCEPTION 'Expected the clean-install base currency to be ARS';
    END IF;

    INSERT INTO users (user_code, email, password_hash, full_name)
    VALUES (
        'CURRENCY-TEST',
        'currency-user@example.test',
        '$test-only$not-a-real-password-hash',
        'Currency Test User'
    )
    RETURNING user_id INTO v_user_id;

    INSERT INTO guests (full_name, email)
    VALUES ('Currency Test Guest', 'currency-test@example.test')
    RETURNING guest_id INTO v_guest_id;

    INSERT INTO properties (property_name, nightly_rate, property_type)
    VALUES ('Currency Test Property', 100.000000, 'ROOM')
    RETURNING property_id INTO v_property_id;

    IF to_regprocedure(
        'create_reservation(bigint,bigint,date,date,bigint,character varying,numeric)'
    ) IS NOT NULL THEN
        RAISE EXCEPTION 'The ambiguous seven-argument currency overload still exists';
    END IF;

    -- Build the call from IDs owned by this transaction. The resulting SQL
    -- still contains untyped integer literals in every numeric position, so
    -- it exercises the overload resolution that previously failed without
    -- depending on seed-row identifiers.
    EXECUTE format(
        'SELECT create_reservation(%s, %s, CURRENT_DATE + 50, '
        'CURRENT_DATE + 51, 100, %L, %s)',
        v_guest_id,
        v_property_id,
        'CASH',
        v_user_id
    )
    INTO v_literal_reservation_id;

    IF NOT EXISTS (
        SELECT 1
        FROM reservations AS r
        JOIN payments AS p USING (reservation_id)
        WHERE r.reservation_id = v_literal_reservation_id
          AND r.status = 'CONFIRMED'
          AND r.currency_code = 'ARS'
          AND r.exchange_rate = 1.0000000000
          AND r.total_amount = 100.000000
          AND p.payment_amount = 100.000000
          AND p.exchange_rate = 1.0000000000
          AND p.status = 'PAID'
    ) THEN
        RAISE EXCEPTION 'Legacy integer-literal creation call is incorrect';
    END IF;

    -- Explicit-currency unpaid creation without services uses the
    -- unambiguous eight-argument form with a NULL JSONB services argument.
    v_reservation_id := create_reservation(
        v_guest_id,
        v_property_id,
        CURRENT_DATE + 100,
        CURRENT_DATE + 103,
        v_user_id,
        NULL::JSONB,
        'USD'::VARCHAR(3),
        1500.0000000000
    );

    IF NOT EXISTS (
        SELECT 1 FROM reservations
        WHERE reservation_id = v_reservation_id
          AND currency_code = 'USD'
          AND exchange_rate = 1500.0000000000
          AND scale(exchange_rate) = 10
          AND total_amount = 300.000000
          AND status = 'PENDING'
    ) THEN
        RAISE EXCEPTION 'Foreign-currency reservation snapshot is incorrect';
    END IF;

    IF calculate_reservation_potential_value_in_base_currency(v_reservation_id)
           <> 450000.000000 THEN
        RAISE EXCEPTION 'Potential base-currency value is incorrect';
    END IF;

    v_payment_id := process_reservation_payment(
        v_reservation_id, 100.000000, 'CREDIT_CARD', 1490.0000000000
    );

    IF calculate_reservation_balance(v_reservation_id) <> 200.000000
       OR (SELECT status FROM reservations WHERE reservation_id = v_reservation_id)
           <> 'PENDING'
       OR (SELECT exchange_rate FROM payments WHERE payment_id = v_payment_id)
           <> 1490.0000000000 THEN
        RAISE EXCEPTION 'First partial payment is incorrect';
    END IF;

    PERFORM process_reservation_payment(
        v_reservation_id, 150.000000, 'BANK_TRANSFER', 1510.0000000000
    );

    IF calculate_reservation_amount_paid(v_reservation_id) <> 250.000000
       OR calculate_reservation_balance(v_reservation_id) <> 50.000000
       OR (SELECT status FROM reservations WHERE reservation_id = v_reservation_id)
           <> 'PENDING' THEN
        RAISE EXCEPTION 'Second partial payment is incorrect';
    END IF;

    v_rejected := FALSE;
    BEGIN
        PERFORM process_reservation_payment(
            v_reservation_id, 50.010000, 'OVERPAY', 1515.0000000000
        );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> 'Payment amount exceeds the outstanding balance.' THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;

    IF NOT v_rejected OR calculate_reservation_amount_paid(v_reservation_id) <> 250.000000 THEN
        RAISE EXCEPTION 'Overpayment rejection was not atomic';
    END IF;

    PERFORM process_reservation_payment(
        v_reservation_id, 50.000000, 'CASH', 1520.0000000000
    );

    IF calculate_reservation_balance(v_reservation_id) <> 0.000000
       OR (SELECT status FROM reservations WHERE reservation_id = v_reservation_id)
           <> 'CONFIRMED'
       OR (SELECT COUNT(*) FROM payments
           WHERE reservation_id = v_reservation_id AND status = 'PAID') <> 3 THEN
        RAISE EXCEPTION 'Final partial payment did not settle the reservation';
    END IF;

    IF calculate_reservation_collected_value_in_base_currency(v_reservation_id)
           <> 451500.000000 THEN
        RAISE EXCEPTION 'Collected base-currency value is incorrect';
    END IF;

    v_rejected := FALSE;
    BEGIN
        PERFORM initialize_reservation(
            v_guest_id, v_property_id, CURRENT_DATE + 200, CURRENT_DATE + 201,
            v_user_id, 'ARS'::VARCHAR(3), 1.0000000001
        );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> 'Exchange rate must be 1 when the currency is the base currency (ARS).' THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;

    IF NOT v_rejected THEN
        RAISE EXCEPTION 'A non-1 base-currency rate was accepted';
    END IF;

    v_rejected := FALSE;
    BEGIN
        PERFORM process_reservation_payment(
            v_reservation_id, 1.000000, 'CASH'
        );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> 'An exchange rate is required for a foreign-currency payment.' THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;

    IF NOT v_rejected THEN
        RAISE EXCEPTION 'Foreign-currency payment omitted its rate snapshot';
    END IF;

    -- Direct base-currency writes may omit both reservation snapshot fields
    -- and the payment rate; the triggers must populate rate 1.
    INSERT INTO reservations (
        guest_id, property_id, check_in_date, check_out_date, status,
        total_amount, created_by_user_id
    )
    VALUES (
        v_guest_id, v_property_id, CURRENT_DATE + 300, CURRENT_DATE + 301,
        'PENDING', 100.000000, v_user_id
    )
    RETURNING reservation_id INTO v_direct_reservation_id;

    IF NOT EXISTS (
        SELECT 1 FROM reservations
        WHERE reservation_id = v_direct_reservation_id
          AND currency_code = 'ARS'
          AND exchange_rate = 1.0000000000
    ) THEN
        RAISE EXCEPTION 'Direct reservation write did not inherit the base currency';
    END IF;

    INSERT INTO payments (
        reservation_id, payment_amount, payment_method, status
    )
    VALUES (v_direct_reservation_id, 10.000000, 'DIRECT', 'PAID')
    RETURNING payment_id INTO v_payment_id;

    IF (SELECT exchange_rate FROM payments WHERE payment_id = v_payment_id)
           <> 1.0000000000 THEN
        RAISE EXCEPTION 'Direct base-currency payment did not inherit rate 1';
    END IF;

    v_rejected := FALSE;
    BEGIN
        INSERT INTO reservations (
            guest_id, property_id, check_in_date, check_out_date, status,
            total_amount, currency_code, exchange_rate, created_by_user_id
        )
        VALUES (
            v_guest_id, v_property_id, CURRENT_DATE + 400, CURRENT_DATE + 401,
            'PENDING', 100.000000, 'ARS', 1.0000000001, v_user_id
        );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> 'Exchange rate must be 1 when the currency is the base currency (ARS).' THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;

    IF NOT v_rejected THEN
        RAISE EXCEPTION 'Direct reservation write accepted a non-1 base rate';
    END IF;

    v_rejected := FALSE;
    BEGIN
        INSERT INTO payments (
            reservation_id, payment_amount, payment_method, status
        )
        VALUES (v_reservation_id, 1.000000, 'DIRECT', 'PAID');
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> 'Exchange rate must be greater than zero.' THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;

    IF NOT v_rejected THEN
        RAISE EXCEPTION 'Direct foreign-currency payment omitted its rate';
    END IF;

    -- The full creation overload keeps reservation-time and payment-time
    -- snapshots independent and permits an initial partial payment.
    v_reservation_id := create_reservation(
        v_guest_id,
        v_property_id,
        CURRENT_DATE + 500,
        CURRENT_DATE + 501,
        40.000000,
        'INITIAL_PARTIAL',
        v_user_id,
        NULL::JSONB,
        'BRL'::VARCHAR(3),
        0.2000000000,
        0.2100000000
    );

    IF NOT EXISTS (
        SELECT 1
        FROM reservations AS r
        JOIN payments AS p USING (reservation_id)
        WHERE r.reservation_id = v_reservation_id
          AND r.currency_code = 'BRL'
          AND r.exchange_rate = 0.2000000000
          AND p.exchange_rate = 0.2100000000
          AND r.status = 'PENDING'
          AND calculate_reservation_balance(r.reservation_id) = 60.000000
    ) THEN
        RAISE EXCEPTION 'Explicit-currency partial creation is incorrect';
    END IF;

    -- A small rate retains ten fractional digits and is never reduced to the
    -- six-decimal monetary scale before conversion.
    PERFORM validate_currency_exchange_rate('BRL', 0.0006666667);

    IF (SELECT data_type = 'numeric' AND numeric_precision = 20
               AND numeric_scale = 10
        FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'payments'
          AND column_name = 'exchange_rate') IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'Payment exchange-rate precision is incorrect';
    END IF;
END;
$$;

ROLLBACK;
