-- Run after installing the consolidated Development Lab schema.
-- All generated rows and catalog changes are rolled back.

BEGIN;

DO $$
DECLARE
    v_user_id              BIGINT;
    v_guest_id             BIGINT;
    v_second_guest_id      BIGINT;
    v_third_guest_id       BIGINT;
    v_fourth_guest_id      BIGINT;
    v_fifth_guest_id       BIGINT;
    v_sixth_guest_id       BIGINT;
    v_property_id          BIGINT;
    v_second_property_id   BIGINT;
    v_service_id           BIGINT;
    v_other_service_id     BIGINT;
    v_reservation_id       BIGINT;
    v_second_reservation_id BIGINT;
    v_pending_reservation_id BIGINT;
    v_service_pending_id   BIGINT;
    v_payment_id           BIGINT;
    v_accommodation        NUMERIC(16,6);
    v_total                NUMERIC(16,6);
    v_paid                 NUMERIC(16,6);
    v_balance              NUMERIC(16,6);
    v_old_payment          NUMERIC(16,6);
    v_rejected             BOOLEAN;
    v_error_message        TEXT;
    v_reservation_count    BIGINT;
BEGIN
    SELECT user_id INTO STRICT v_user_id
    FROM users WHERE user_code = 'CALVAREZ';

    INSERT INTO guests (full_name, email)
    VALUES ('Economic Lifecycle Guest', 'economic-lifecycle@example.test')
    RETURNING guest_id INTO v_guest_id;

    INSERT INTO guests (full_name, email)
    VALUES ('Economic Lifecycle Guest 2', 'economic-lifecycle-2@example.test')
    RETURNING guest_id INTO v_second_guest_id;

    INSERT INTO guests (full_name, email)
    VALUES ('Economic Lifecycle Guest 3', 'economic-lifecycle-3@example.test')
    RETURNING guest_id INTO v_third_guest_id;

    INSERT INTO guests (full_name, email)
    VALUES ('Economic Lifecycle Guest 4', 'economic-lifecycle-4@example.test')
    RETURNING guest_id INTO v_fourth_guest_id;

    INSERT INTO guests (full_name, email)
    VALUES ('Economic Lifecycle Guest 5', 'economic-lifecycle-5@example.test')
    RETURNING guest_id INTO v_fifth_guest_id;

    INSERT INTO guests (full_name, email)
    VALUES ('Economic Lifecycle Guest 6', 'economic-lifecycle-6@example.test')
    RETURNING guest_id INTO v_sixth_guest_id;

    INSERT INTO properties (property_name, nightly_rate, property_type)
    VALUES ('Precision Property', 10.123456, 'ROOM')
    RETURNING property_id INTO v_property_id;

    INSERT INTO properties (property_name, nightly_rate, property_type)
    VALUES ('Temporal Rules Property', 20.000001, 'ROOM')
    RETURNING property_id INTO v_second_property_id;

    INSERT INTO services (service_name, description, price)
    VALUES ('Precision Service', 'Six-decimal lifecycle test', 1.234567)
    RETURNING service_id INTO v_service_id;

    INSERT INTO services (service_name, description, price)
    VALUES ('Other Precision Service', 'Six-decimal lifecycle test', 2.000001)
    RETURNING service_id INTO v_other_service_id;

    -- The lower-level domain operation remains directly usable when callers
    -- explicitly need initialization semantics.
    v_second_reservation_id := initialize_reservation(
        v_second_guest_id,
        v_second_property_id,
        CURRENT_DATE + 40,
        CURRENT_DATE + 42,
        v_user_id
    );
    v_accommodation := calculate_booking_total(
        v_second_property_id,
        CURRENT_DATE + 40,
        CURRENT_DATE + 42
    )::NUMERIC(16,6);
    IF (SELECT status FROM reservations
        WHERE reservation_id = v_second_reservation_id) <> 'PENDING'
       OR (SELECT total_amount FROM reservations
           WHERE reservation_id = v_second_reservation_id) <> v_accommodation THEN
        RAISE EXCEPTION 'Direct reservation initialization is incorrect';
    END IF;

    -- Public creation without services or payment leaves a complete
    -- accommodation-only PENDING reservation.
    v_pending_reservation_id := create_reservation(
        v_third_guest_id,
        v_property_id,
        CURRENT_DATE + 50,
        CURRENT_DATE + 52,
        v_user_id
    );
    v_accommodation := calculate_booking_total(
        v_property_id,
        CURRENT_DATE + 50,
        CURRENT_DATE + 52
    )::NUMERIC(16,6);
    IF (SELECT status FROM reservations
        WHERE reservation_id = v_pending_reservation_id) <> 'PENDING'
       OR (SELECT total_amount FROM reservations
           WHERE reservation_id = v_pending_reservation_id) <> v_accommodation
       OR EXISTS (SELECT 1 FROM reservation_services
                  WHERE reservation_id = v_pending_reservation_id)
       OR EXISTS (SELECT 1 FROM payments
                  WHERE reservation_id = v_pending_reservation_id) THEN
        RAISE EXCEPTION 'Creation without services or payment is incorrect';
    END IF;

    -- Public creation with services but no payment also remains PENDING and
    -- stores the full accommodation-plus-snapshot total.
    v_service_pending_id := create_reservation(
        v_fourth_guest_id,
        v_property_id,
        CURRENT_DATE + 60,
        CURRENT_DATE + 62,
        v_user_id,
        jsonb_build_array(jsonb_build_object(
            'service_id', v_service_id,
            'quantity', 2
        ))
    );
    v_accommodation := calculate_booking_total(
        v_property_id,
        CURRENT_DATE + 60,
        CURRENT_DATE + 62
    )::NUMERIC(16,6);
    v_total := (v_accommodation + 2 * 1.234567)::NUMERIC(16,6);
    IF (SELECT status FROM reservations
        WHERE reservation_id = v_service_pending_id) <> 'PENDING'
       OR (SELECT total_amount FROM reservations
           WHERE reservation_id = v_service_pending_id) <> v_total
       OR calculate_reservation_balance(v_service_pending_id) <> v_total
       OR EXISTS (SELECT 1 FROM payments
                  WHERE reservation_id = v_service_pending_id) THEN
        RAISE EXCEPTION 'Creation with services and no payment is incorrect';
    END IF;

    -- The paid public path initializes and settles atomically.
    v_accommodation := calculate_booking_total(
        v_property_id,
        CURRENT_DATE + 100,
        CURRENT_DATE + 102
    )::NUMERIC(16,6);
    v_total := (v_accommodation + 3 * 1.234567)::NUMERIC(16,6);
    v_reservation_id := create_reservation(
        v_guest_id,
        v_property_id,
        CURRENT_DATE + 100,
        CURRENT_DATE + 102,
        v_total,
        '  CREDIT_CARD  ',
        v_user_id,
        jsonb_build_array(jsonb_build_object(
            'service_id', v_service_id,
            'quantity', 3
        ))
    );

    IF calculate_reservation_total(v_reservation_id) <> v_total
       OR (SELECT total_amount FROM reservations
           WHERE reservation_id = v_reservation_id) <> v_total
       OR scale(calculate_reservation_total(v_reservation_id)) <> 6 THEN
        RAISE EXCEPTION 'Accommodation and service total lost six-decimal precision';
    END IF;

    SELECT payment_id, payment_amount
    INTO STRICT v_payment_id, v_old_payment
    FROM payments WHERE reservation_id = v_reservation_id;

    IF v_old_payment <> v_total
       OR scale(v_old_payment) <> 6
       OR calculate_reservation_amount_paid(v_reservation_id) <> v_total
       OR calculate_reservation_balance(v_reservation_id) <> 0.000000
       OR (SELECT status FROM reservations
           WHERE reservation_id = v_reservation_id) <> 'CONFIRMED' THEN
        RAISE EXCEPTION 'Payment, paid amount, balance, or confirmation is incorrect';
    END IF;

    INSERT INTO payments (
        reservation_id, payment_amount, payment_method, status
    ) VALUES
        (v_reservation_id, 7.654321, 'TEST_PENDING', 'PENDING'),
        (v_reservation_id, 8.765432, 'TEST_REFUNDED', 'REFUNDED');

    IF calculate_reservation_amount_paid(v_reservation_id) <> v_total THEN
        RAISE EXCEPTION 'Only PAID payment rows may contribute to amount paid';
    END IF;

    PERFORM replace_reservation_services(
        v_reservation_id,
        jsonb_build_array(
            jsonb_build_object('service_id', v_service_id, 'quantity', 3),
            jsonb_build_object('service_id', v_other_service_id, 'quantity', 2)
        )
    );

    v_balance := calculate_reservation_balance(v_reservation_id)::NUMERIC(16,6);
    IF v_balance <> 4.000002
       OR (SELECT status FROM reservations
           WHERE reservation_id = v_reservation_id) <> 'CONFIRMED'
       OR (SELECT payment_amount FROM payments
           WHERE payment_id = v_payment_id) <> v_old_payment THEN
        RAISE EXCEPTION 'Service addition must create a balance without rewriting history';
    END IF;

    PERFORM process_reservation_payment(
        v_reservation_id,
        v_balance,
        'BANK_TRANSFER'
    );

    IF calculate_reservation_balance(v_reservation_id) <> 0.000000 THEN
        RAISE EXCEPTION 'Follow-up payment did not settle the service balance';
    END IF;

    v_rejected := FALSE;
    BEGIN
        PERFORM process_reservation_payment(
            v_reservation_id, 0.000001, 'NO_BALANCE'
        );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> format(
            'Reservation %s has no positive balance due.', v_reservation_id
        ) THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;
    IF NOT v_rejected THEN
        RAISE EXCEPTION 'A reservation without a positive balance accepted payment';
    END IF;

    UPDATE services SET price = 9.876543 WHERE service_id = v_service_id;
    v_total := (SELECT total_amount FROM reservations
                WHERE reservation_id = v_reservation_id);
    IF calculate_reservation_total(v_reservation_id) <> v_total THEN
        RAISE EXCEPTION 'Catalog price changes must not alter existing snapshots';
    END IF;

    PERFORM replace_reservation_services(
        v_reservation_id,
        jsonb_build_array(
            jsonb_build_object('service_id', v_service_id, 'quantity', 2),
            jsonb_build_object('service_id', v_other_service_id, 'quantity', 1)
        )
    );
    IF (SELECT quantity FROM reservation_services
        WHERE reservation_id = v_reservation_id
          AND service_id = v_service_id) <> 2
       OR (SELECT unit_price FROM reservation_services
           WHERE reservation_id = v_reservation_id
             AND service_id = v_service_id) <> 9.876543 THEN
        RAISE EXCEPTION 'Canonical replacement did not refresh service snapshots';
    END IF;

    v_total := (SELECT total_amount FROM reservations
                WHERE reservation_id = v_reservation_id);
    PERFORM replace_reservation_services(v_reservation_id, NULL::JSONB);
    IF (SELECT total_amount FROM reservations
        WHERE reservation_id = v_reservation_id) <> v_total THEN
        RAISE EXCEPTION 'NULL service input must be a no-op';
    END IF;

    v_rejected := FALSE;
    BEGIN
        PERFORM replace_reservation_services(
            v_reservation_id,
            jsonb_build_array(
                jsonb_build_object('service_id', v_service_id, 'quantity', 1),
                jsonb_build_object('service_id', v_service_id, 'quantity', 2)
            )
        );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> 'The service list contains repeated services.' THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;
    IF NOT v_rejected THEN
        RAISE EXCEPTION 'Repeated JSONB services were accepted';
    END IF;
    IF (SELECT total_amount FROM reservations
        WHERE reservation_id = v_reservation_id) <> v_total THEN
        RAISE EXCEPTION 'Invalid replacement was not atomic';
    END IF;

    v_rejected := FALSE;
    BEGIN
        PERFORM replace_reservation_services(
            v_reservation_id,
            jsonb_build_array(
                jsonb_build_object('service_id', v_service_id, 'quantity', 1),
                jsonb_build_object('service_id', -1, 'quantity', 1)
            )
        );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> 'Service identifier must be a positive integer.' THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;
    IF NOT v_rejected OR (SELECT total_amount FROM reservations
        WHERE reservation_id = v_reservation_id) <> v_total THEN
        RAISE EXCEPTION 'Whole-document validation did not preserve prior state';
    END IF;

    PERFORM replace_reservation_services(v_reservation_id, '[]'::JSONB);
    IF EXISTS (SELECT 1 FROM reservation_services
               WHERE reservation_id = v_reservation_id)
       OR (SELECT total_amount FROM reservations
           WHERE reservation_id = v_reservation_id) <> v_accommodation THEN
        RAISE EXCEPTION 'Empty JSONB must clear services and restore accommodation total';
    END IF;

    v_second_reservation_id := create_reservation(
        v_second_guest_id,
        v_second_property_id,
        CURRENT_DATE - 1,
        CURRENT_DATE,
        v_user_id
    );
    PERFORM replace_reservation_services(
        v_second_reservation_id,
        jsonb_build_array(jsonb_build_object(
            'service_id', v_other_service_id, 'quantity', 1
        ))
    );

    UPDATE reservations
    SET check_in_date = CURRENT_DATE - 3,
        check_out_date = CURRENT_DATE - 2
    WHERE reservation_id = v_second_reservation_id;
    v_rejected := FALSE;
    BEGIN
        PERFORM replace_reservation_services(v_second_reservation_id, '[]'::JSONB);
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> 'Services cannot be changed after checkout.' THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;
    IF NOT v_rejected THEN
        RAISE EXCEPTION 'Service replacement after checkout was accepted';
    END IF;

    UPDATE reservations SET status = 'CANCELLED'
    WHERE reservation_id = v_second_reservation_id;
    v_rejected := FALSE;
    BEGIN
        PERFORM process_reservation_payment(
            v_second_reservation_id, 1.000001, 'CARD'
        );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> format(
            'Cancelled reservation %s cannot receive payments.',
            v_second_reservation_id
        ) THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;
    IF NOT v_rejected THEN
        RAISE EXCEPTION 'Cancelled reservation accepted a payment';
    END IF;
    v_rejected := FALSE;
    BEGIN
        PERFORM replace_reservation_services(
            v_second_reservation_id,
            jsonb_build_array(jsonb_build_object(
                'service_id', v_other_service_id, 'quantity', 1
            ))
        );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> format(
            'Cancelled reservation %s cannot be changed.',
            v_second_reservation_id
        ) THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;
    IF NOT v_rejected THEN
        RAISE EXCEPTION 'Cancelled reservation accepted a service change';
    END IF;

    v_total := (
        calculate_booking_total(
            v_second_property_id,
            CURRENT_DATE + 300,
            CURRENT_DATE + 302
        ) + (2 * 2.000001)
    )::NUMERIC(16,6);
    v_reservation_id := create_reservation(
        v_third_guest_id,
        v_second_property_id,
        CURRENT_DATE + 300,
        CURRENT_DATE + 302,
        v_total,
        'SERVICE_BOOKING',
        v_user_id,
        jsonb_build_array(jsonb_build_object(
            'service_id', v_other_service_id, 'quantity', 2
        ))
    );
    IF calculate_reservation_balance(v_reservation_id) <> 0.000000
       OR (SELECT status FROM reservations
           WHERE reservation_id = v_reservation_id) <> 'CONFIRMED' THEN
        RAISE EXCEPTION 'Service-aware create_reservation did not settle atomically';
    END IF;

    v_total := calculate_booking_total(
        v_property_id,
        CURRENT_DATE + 400,
        CURRENT_DATE + 402
    )::NUMERIC(16,6);
    v_reservation_id := create_reservation(
        v_fourth_guest_id,
        v_property_id,
        CURRENT_DATE + 400,
        CURRENT_DATE + 402,
        v_total,
        'LEGACY_BOOKING',
        v_user_id
    );
    IF calculate_reservation_balance(v_reservation_id) <> 0.000000
       OR EXISTS (SELECT 1 FROM reservation_services
                  WHERE reservation_id = v_reservation_id) THEN
        RAISE EXCEPTION 'Accommodation-only paid creation is incorrect';
    END IF;

    -- Rejected settlement rolls back initialization as part of the same call.
    SELECT COUNT(*) INTO v_reservation_count FROM reservations;
    v_total := calculate_booking_total(
        v_property_id,
        CURRENT_DATE + 500,
        CURRENT_DATE + 502
    )::NUMERIC(16,6);
    v_rejected := FALSE;
    BEGIN
        PERFORM create_reservation(
            v_fifth_guest_id,
            v_property_id,
            CURRENT_DATE + 500,
            CURRENT_DATE + 502,
            (v_total - 0.02)::NUMERIC(16,6),
            'PARTIAL_PAYMENT',
            v_user_id
        );
        RAISE EXCEPTION 'A partial payment was accepted';
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> 'Payment amount does not match the outstanding balance.' THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;
    IF NOT v_rejected
       OR (SELECT COUNT(*) FROM reservations) <> v_reservation_count THEN
        RAISE EXCEPTION 'Partial-payment creation was not rejected atomically';
    END IF;

    v_total := (
        calculate_booking_total(
            v_second_property_id,
            CURRENT_DATE + 600,
            CURRENT_DATE + 602
        ) + 2.000001
    )::NUMERIC(16,6);
    v_rejected := FALSE;
    BEGIN
        PERFORM create_reservation(
            v_sixth_guest_id,
            v_second_property_id,
            CURRENT_DATE + 600,
            CURRENT_DATE + 602,
            (v_total + 0.02)::NUMERIC(16,6),
            'OVERPAYMENT',
            v_user_id,
            jsonb_build_array(jsonb_build_object(
                'service_id', v_other_service_id,
                'quantity', 1
            ))
        );
        RAISE EXCEPTION 'An overpayment was accepted';
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> 'Payment amount does not match the outstanding balance.' THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;
    IF NOT v_rejected
       OR (SELECT COUNT(*) FROM reservations) <> v_reservation_count THEN
        RAISE EXCEPTION 'Overpayment creation was not rejected atomically';
    END IF;

    IF to_regprocedure('initialize_reservation(bigint,bigint,date,date,bigint)') IS NULL
       OR to_regprocedure('initialize_reservation(bigint,bigint,date,date,bigint,jsonb)') IS NULL
       OR to_regprocedure('create_reservation(bigint,bigint,date,date,bigint)') IS NULL
       OR to_regprocedure('create_reservation(bigint,bigint,date,date,bigint,jsonb)') IS NULL
       OR to_regprocedure('create_reservation(bigint,bigint,date,date,numeric,character varying,bigint)') IS NULL
       OR to_regprocedure('create_reservation(bigint,bigint,date,date,numeric,character varying,bigint,jsonb)') IS NULL
       OR to_regprocedure('process_reservation_payment(bigint,numeric,character varying)') IS NULL THEN
        RAISE EXCEPTION 'A required final creation signature is missing';
    END IF;
    IF to_regprocedure('process_booking(bigint,bigint,date,date,numeric,character varying,bigint)') IS NOT NULL
       OR to_regprocedure('process_booking(bigint,bigint,date,date,numeric,character varying,bigint,jsonb)') IS NOT NULL
       OR to_regprocedure('add_services_to_reservation(bigint,bigint[])') IS NOT NULL
       OR to_regprocedure('add_services_to_reservation(bigint,jsonb)') IS NOT NULL THEN
        RAISE EXCEPTION 'An obsolete booking or service wrapper remains installed';
    END IF;

    -- This value differs from the balance below the 0.01 settlement tolerance
    -- but is stored and compared at six decimals, not rounded to cents.
    v_second_reservation_id := create_reservation(
        v_second_guest_id,
        v_property_id,
        CURRENT_DATE + 200,
        CURRENT_DATE + 202,
        v_user_id
    );
    v_balance := calculate_reservation_balance(v_second_reservation_id);
    v_rejected := FALSE;
    BEGIN
        PERFORM process_reservation_payment(
            v_second_reservation_id, v_balance, '   '
        );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> 'Payment method cannot be blank.' THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;
    IF NOT v_rejected THEN
        RAISE EXCEPTION 'A blank payment method was accepted';
    END IF;
    v_payment_id := process_reservation_payment(
        v_second_reservation_id,
        (v_balance - 0.000001)::NUMERIC(16,6),
        'PRECISION_TEST'
    );
    IF (SELECT payment_amount FROM payments WHERE payment_id = v_payment_id)
           <> (v_balance - 0.000001)::NUMERIC(16,6)
       OR calculate_reservation_balance(v_second_reservation_id) <> 0.000001 THEN
        RAISE EXCEPTION 'Settlement tolerance incorrectly rounded monetary values';
    END IF;

    v_rejected := FALSE;
    BEGIN
        PERFORM process_reservation_payment(
            v_second_reservation_id, 0.010001, 'OVERPAY'
        );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> 'Payment amount does not match the outstanding balance.' THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;
    IF NOT v_rejected THEN
        RAISE EXCEPTION 'A payment outside the settlement tolerance was accepted';
    END IF;

    UPDATE services SET is_active = FALSE
    WHERE service_id = v_other_service_id;
    v_rejected := FALSE;
    BEGIN
        PERFORM replace_reservation_services(
            v_reservation_id,
            jsonb_build_array(jsonb_build_object(
                'service_id', v_other_service_id, 'quantity', 1
            ))
        );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> format('Service %s is inactive.', v_other_service_id) THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;
    IF NOT v_rejected THEN
        RAISE EXCEPTION 'An inactive service was accepted for a new snapshot';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'reservations'
          AND column_name IN ('amount_paid', 'balance_due')
    ) THEN
        RAISE EXCEPTION 'Derived economic values must not be persisted columns';
    END IF;
END;
$$;

ROLLBACK;
