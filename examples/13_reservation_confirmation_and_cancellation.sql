-- Run after installing the consolidated Development Lab schema.
-- All generated rows are rolled back.

BEGIN;

DO $$
DECLARE
    v_user_id                   BIGINT;
    v_guest_id                  BIGINT;
    v_property_id               BIGINT;
    v_nonexistent_id            CONSTANT BIGINT := -1;
    v_no_payment_id             BIGINT;
    v_partial_id                BIGINT;
    v_settled_id                BIGINT;
    v_exact_tolerance_id        BIGINT;
    v_within_tolerance_id       BIGINT;
    v_pending_cancellation_id   BIGINT;
    v_automatic_confirmation_id BIGINT;
    v_preserved_payment_id      BIGINT;
    v_payment_count             BIGINT;
    v_rejected                  BOOLEAN;
    v_error_message             TEXT;
BEGIN
    INSERT INTO users (
        user_code, email, password_hash, full_name
    ) VALUES (
        'STATUS-LIFECYCLE-TEST',
        'status-lifecycle-user@example.test',
        '$test-only$not-a-real-password-hash',
        'Status Lifecycle Test User'
    )
    RETURNING user_id INTO v_user_id;

    INSERT INTO guests (full_name, email)
    VALUES ('Status Lifecycle Test Guest', 'status-lifecycle-guest@example.test')
    RETURNING guest_id INTO v_guest_id;

    INSERT INTO properties (property_name, nightly_rate, property_type)
    VALUES ('Status Lifecycle Test Property', 100.000000, 'ROOM')
    RETURNING property_id INTO v_property_id;

    v_rejected := FALSE;
    BEGIN
        PERFORM confirm_reservation(v_nonexistent_id);
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> format(
            'Reservation %s not found.', v_nonexistent_id
        ) THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;

    IF NOT v_rejected THEN
        RAISE EXCEPTION 'Confirmation accepted a nonexistent reservation';
    END IF;

    v_rejected := FALSE;
    BEGIN
        PERFORM cancel_reservation(v_nonexistent_id);
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> format(
            'Reservation %s not found.', v_nonexistent_id
        ) THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;

    IF NOT v_rejected THEN
        RAISE EXCEPTION 'Cancellation accepted a nonexistent reservation';
    END IF;

    INSERT INTO reservations (
        guest_id, property_id, created_by_user_id,
        check_in_date, check_out_date, status, total_amount,
        currency_code, exchange_rate, updated_at
    ) VALUES (
        v_guest_id, v_property_id, v_user_id,
        CURRENT_DATE + 100, CURRENT_DATE + 101, 'PENDING', 100.000000,
        'ARS', 1.0000000000, CURRENT_TIMESTAMP - INTERVAL '1 day'
    )
    RETURNING reservation_id INTO v_no_payment_id;

    v_rejected := FALSE;
    BEGIN
        PERFORM confirm_reservation(v_no_payment_id);
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> format(
            'Reservation %s cannot be confirmed because its outstanding balance is not settled.',
            v_no_payment_id
        ) THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;

    IF NOT v_rejected
       OR (SELECT status FROM reservations WHERE reservation_id = v_no_payment_id)
            <> 'PENDING' THEN
        RAISE EXCEPTION 'An unpaid reservation was confirmed';
    END IF;

    INSERT INTO reservations (
        guest_id, property_id, created_by_user_id,
        check_in_date, check_out_date, status, total_amount,
        currency_code, exchange_rate, updated_at
    ) VALUES (
        v_guest_id, v_property_id, v_user_id,
        CURRENT_DATE + 200, CURRENT_DATE + 201, 'PENDING', 100.000000,
        'ARS', 1.0000000000, CURRENT_TIMESTAMP - INTERVAL '1 day'
    )
    RETURNING reservation_id INTO v_partial_id;

    PERFORM process_reservation_payment(
        v_partial_id, 50.000000, 'PARTIAL_TEST', 1.0000000000
    );

    v_rejected := FALSE;
    BEGIN
        PERFORM confirm_reservation(v_partial_id);
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> format(
            'Reservation %s cannot be confirmed because its outstanding balance is not settled.',
            v_partial_id
        ) THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;

    IF NOT v_rejected
       OR calculate_reservation_balance(v_partial_id) <> 50.000000
       OR (SELECT status FROM reservations WHERE reservation_id = v_partial_id)
            <> 'PENDING' THEN
        RAISE EXCEPTION 'A partially paid reservation was confirmed';
    END IF;

    INSERT INTO reservations (
        guest_id, property_id, created_by_user_id,
        check_in_date, check_out_date, status, total_amount,
        currency_code, exchange_rate, updated_at
    ) VALUES (
        v_guest_id, v_property_id, v_user_id,
        CURRENT_DATE + 300, CURRENT_DATE + 301, 'PENDING', 100.000000,
        'ARS', 1.0000000000, CURRENT_TIMESTAMP - INTERVAL '1 day'
    )
    RETURNING reservation_id INTO v_settled_id;

    INSERT INTO payments (
        reservation_id, payment_amount, exchange_rate, payment_method, status
    ) VALUES (
        v_settled_id, 100.000000, 1.0000000000, 'SETTLED_TEST', 'PAID'
    )
    RETURNING payment_id INTO v_preserved_payment_id;

    PERFORM confirm_reservation(v_settled_id);

    IF calculate_reservation_balance(v_settled_id) <> 0.000000
       OR (SELECT status FROM reservations WHERE reservation_id = v_settled_id)
            <> 'CONFIRMED' THEN
        RAISE EXCEPTION 'A settled reservation was not confirmed';
    END IF;

    INSERT INTO reservations (
        guest_id, property_id, created_by_user_id,
        check_in_date, check_out_date, status, total_amount,
        currency_code, exchange_rate, updated_at
    ) VALUES (
        v_guest_id, v_property_id, v_user_id,
        CURRENT_DATE + 400, CURRENT_DATE + 401, 'PENDING', 100.000000,
        'ARS', 1.0000000000, CURRENT_TIMESTAMP - INTERVAL '1 day'
    )
    RETURNING reservation_id INTO v_exact_tolerance_id;

    INSERT INTO payments (
        reservation_id, payment_amount, exchange_rate, payment_method, status
    ) VALUES (
        v_exact_tolerance_id, 99.990000, 1.0000000000,
        'EXACT_TOLERANCE_TEST', 'PAID'
    );

    v_rejected := FALSE;
    BEGIN
        PERFORM confirm_reservation(v_exact_tolerance_id);
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> format(
            'Reservation %s cannot be confirmed because its outstanding balance is not settled.',
            v_exact_tolerance_id
        ) THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;

    IF NOT v_rejected
       OR calculate_reservation_balance(v_exact_tolerance_id) <> 0.010000
       OR (SELECT status FROM reservations
           WHERE reservation_id = v_exact_tolerance_id) <> 'PENDING' THEN
        RAISE EXCEPTION 'The exact 0.01 balance boundary was accepted';
    END IF;

    INSERT INTO reservations (
        guest_id, property_id, created_by_user_id,
        check_in_date, check_out_date, status, total_amount,
        currency_code, exchange_rate, updated_at
    ) VALUES (
        v_guest_id, v_property_id, v_user_id,
        CURRENT_DATE + 500, CURRENT_DATE + 501, 'PENDING', 100.000000,
        'ARS', 1.0000000000, CURRENT_TIMESTAMP - INTERVAL '1 day'
    )
    RETURNING reservation_id INTO v_within_tolerance_id;

    INSERT INTO payments (
        reservation_id, payment_amount, exchange_rate, payment_method, status
    ) VALUES (
        v_within_tolerance_id, 99.990001, 1.0000000000,
        'WITHIN_TOLERANCE_TEST', 'PAID'
    );

    PERFORM confirm_reservation(v_within_tolerance_id);

    IF calculate_reservation_balance(v_within_tolerance_id) <> 0.009999
       OR (SELECT status FROM reservations
           WHERE reservation_id = v_within_tolerance_id) <> 'CONFIRMED' THEN
        RAISE EXCEPTION 'A balance within the settlement tolerance was rejected';
    END IF;

    INSERT INTO reservations (
        guest_id, property_id, created_by_user_id,
        check_in_date, check_out_date, status, total_amount,
        currency_code, exchange_rate, updated_at
    ) VALUES (
        v_guest_id, v_property_id, v_user_id,
        CURRENT_DATE + 600, CURRENT_DATE + 601, 'PENDING', 100.000000,
        'ARS', 1.0000000000, CURRENT_TIMESTAMP - INTERVAL '1 day'
    )
    RETURNING reservation_id INTO v_pending_cancellation_id;

    PERFORM cancel_reservation(v_pending_cancellation_id);

    IF (SELECT status FROM reservations
        WHERE reservation_id = v_pending_cancellation_id) <> 'CANCELLED'
       OR NOT EXISTS (
           SELECT 1
           FROM reservation_status_audit
           WHERE reservation_id = v_pending_cancellation_id
             AND old_status = 'PENDING'
             AND new_status = 'CANCELLED'
       )
       OR (SELECT updated_at FROM reservations
           WHERE reservation_id = v_pending_cancellation_id)
            <= CURRENT_TIMESTAMP - INTERVAL '1 day' THEN
        RAISE EXCEPTION 'Pending cancellation did not update status metadata';
    END IF;

    SELECT COUNT(*) INTO v_payment_count
    FROM payments
    WHERE reservation_id = v_settled_id;

    PERFORM cancel_reservation(v_settled_id);

    IF (SELECT status FROM reservations WHERE reservation_id = v_settled_id)
            <> 'CANCELLED'
       OR (SELECT COUNT(*) FROM payments WHERE reservation_id = v_settled_id)
            <> v_payment_count
       OR NOT EXISTS (
           SELECT 1
           FROM payments
           WHERE payment_id = v_preserved_payment_id
             AND reservation_id = v_settled_id
             AND payment_amount = 100.000000
             AND exchange_rate = 1.0000000000
             AND payment_method = 'SETTLED_TEST'
             AND status = 'PAID'
       )
       OR NOT EXISTS (
           SELECT 1
           FROM reservation_status_audit
           WHERE reservation_id = v_settled_id
             AND old_status = 'CONFIRMED'
             AND new_status = 'CANCELLED'
       )
       OR (SELECT updated_at FROM reservations WHERE reservation_id = v_settled_id)
            <= CURRENT_TIMESTAMP - INTERVAL '1 day' THEN
        RAISE EXCEPTION 'Confirmed cancellation changed economic history or missed metadata';
    END IF;

    v_rejected := FALSE;
    BEGIN
        PERFORM cancel_reservation(v_settled_id);
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> 'Reservation is already cancelled.' THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;

    IF NOT v_rejected THEN
        RAISE EXCEPTION 'Repeated cancellation was accepted';
    END IF;

    v_rejected := FALSE;
    BEGIN
        PERFORM process_reservation_payment(
            v_settled_id, 1.000000, 'CANCELLED_PAYMENT_TEST', 1.0000000000
        );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> format(
            'Cancelled reservation %s cannot receive payments.', v_settled_id
        ) THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;

    IF NOT v_rejected
       OR (SELECT COUNT(*) FROM payments WHERE reservation_id = v_settled_id)
            <> v_payment_count THEN
        RAISE EXCEPTION 'Cancelled reservation accepted or changed a payment';
    END IF;

    INSERT INTO reservations (
        guest_id, property_id, created_by_user_id,
        check_in_date, check_out_date, status, total_amount,
        currency_code, exchange_rate, updated_at
    ) VALUES (
        v_guest_id, v_property_id, v_user_id,
        CURRENT_DATE + 700, CURRENT_DATE + 701, 'PENDING', 100.000000,
        'ARS', 1.0000000000, CURRENT_TIMESTAMP - INTERVAL '1 day'
    )
    RETURNING reservation_id INTO v_automatic_confirmation_id;

    PERFORM process_reservation_payment(
        v_automatic_confirmation_id,
        100.000000,
        'AUTOMATIC_CONFIRMATION_TEST',
        1.0000000000
    );

    IF calculate_reservation_balance(v_automatic_confirmation_id) <> 0.000000
       OR (SELECT status FROM reservations
           WHERE reservation_id = v_automatic_confirmation_id) <> 'CONFIRMED'
       OR NOT EXISTS (
           SELECT 1
           FROM reservation_status_audit
           WHERE reservation_id = v_automatic_confirmation_id
             AND old_status = 'PENDING'
             AND new_status = 'CONFIRMED'
       )
       OR (SELECT updated_at FROM reservations
           WHERE reservation_id = v_automatic_confirmation_id)
            <= CURRENT_TIMESTAMP - INTERVAL '1 day' THEN
        RAISE EXCEPTION 'Payment settlement did not confirm and audit atomically';
    END IF;
END;
$$;

ROLLBACK;
