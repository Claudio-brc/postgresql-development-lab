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
    v_property_id          BIGINT;
    v_second_property_id   BIGINT;
    v_service_id           BIGINT;
    v_other_service_id     BIGINT;
    v_reservation_id       BIGINT;
    v_second_reservation_id BIGINT;
    v_payment_id           BIGINT;
    v_accommodation        NUMERIC(16,6);
    v_total                NUMERIC(16,6);
    v_paid                 NUMERIC(16,6);
    v_balance              NUMERIC(16,6);
    v_old_payment          NUMERIC(16,6);
    v_rejected             BOOLEAN;
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

    v_reservation_id := create_reservation(
        v_guest_id,
        v_property_id,
        CURRENT_DATE + 100,
        CURRENT_DATE + 102,
        v_user_id,
        jsonb_build_array(jsonb_build_object(
            'service_id', v_service_id,
            'quantity', 3
        ))
    );

    v_accommodation := calculate_booking_total(
        v_property_id,
        CURRENT_DATE + 100,
        CURRENT_DATE + 102
    )::NUMERIC(16,6);
    v_total := (v_accommodation + 3 * 1.234567)::NUMERIC(16,6);

    IF calculate_reservation_total(v_reservation_id) <> v_total
       OR (SELECT total_amount FROM reservations
           WHERE reservation_id = v_reservation_id) <> v_total
       OR scale(calculate_reservation_total(v_reservation_id)) <> 6 THEN
        RAISE EXCEPTION 'Accommodation and service total lost six-decimal precision';
    END IF;

    v_payment_id := process_reservation_payment(
        v_reservation_id,
        v_total,
        '  CREDIT_CARD  '
    );

    SELECT payment_amount INTO v_old_payment
    FROM payments WHERE payment_id = v_payment_id;

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
    EXCEPTION WHEN OTHERS THEN
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

    PERFORM add_services_to_reservation(
        v_reservation_id,
        ARRAY[v_service_id, v_service_id, v_other_service_id]
    );
    IF (SELECT quantity FROM reservation_services
        WHERE reservation_id = v_reservation_id
          AND service_id = v_service_id) <> 2
       OR (SELECT unit_price FROM reservation_services
           WHERE reservation_id = v_reservation_id
             AND service_id = v_service_id) <> 9.876543 THEN
        RAISE EXCEPTION 'ARRAY replacement did not consolidate IDs or refresh snapshots';
    END IF;

    v_total := (SELECT total_amount FROM reservations
                WHERE reservation_id = v_reservation_id);
    PERFORM add_services_to_reservation(v_reservation_id, NULL::BIGINT[]);
    PERFORM add_services_to_reservation(v_reservation_id, NULL::JSONB);
    IF (SELECT total_amount FROM reservations
        WHERE reservation_id = v_reservation_id) <> v_total THEN
        RAISE EXCEPTION 'NULL compatibility inputs must be no-ops';
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
    EXCEPTION WHEN OTHERS THEN
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
    EXCEPTION WHEN OTHERS THEN
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
    PERFORM add_services_to_reservation(v_reservation_id, ARRAY[]::BIGINT[]);

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
    EXCEPTION WHEN OTHERS THEN
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
    EXCEPTION WHEN OTHERS THEN
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
    EXCEPTION WHEN OTHERS THEN
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
    v_reservation_id := process_booking(
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
        RAISE EXCEPTION 'Service-aware process_booking did not complete atomically';
    END IF;

    v_total := calculate_booking_total(
        v_property_id,
        CURRENT_DATE + 400,
        CURRENT_DATE + 402
    )::NUMERIC(16,6);
    v_reservation_id := process_booking(
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
        RAISE EXCEPTION 'Legacy process_booking compatibility changed';
    END IF;

    IF to_regprocedure('create_reservation(bigint,bigint,date,date,bigint)') IS NULL
       OR to_regprocedure('create_reservation(bigint,bigint,date,date,bigint,jsonb)') IS NULL
       OR to_regprocedure('process_booking(bigint,bigint,date,date,numeric,character varying,bigint)') IS NULL
       OR to_regprocedure('process_booking(bigint,bigint,date,date,numeric,character varying,bigint,jsonb)') IS NULL
       OR to_regprocedure('process_reservation_payment(bigint,numeric,character varying)') IS NULL THEN
        RAISE EXCEPTION 'A required legacy or evolved signature is missing';
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
    EXCEPTION WHEN OTHERS THEN
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
    EXCEPTION WHEN OTHERS THEN
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
    EXCEPTION WHEN OTHERS THEN
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
