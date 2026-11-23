-- Run after installing the consolidated Development Lab schema.
-- All generated rows are rolled back.

BEGIN;

DO $$
DECLARE
    v_user_id               BIGINT;
    v_guest_id              BIGINT;
    v_second_guest_id       BIGINT;
    v_third_guest_id        BIGINT;
    v_property_id           BIGINT;
    v_inactive_property_id  BIGINT;
    v_reservation_id        BIGINT;
    v_paid_reservation_id   BIGINT;
    v_legacy_reservation_id BIGINT;
    v_expected_total        NUMERIC(16,6);
    v_invalid_guests        INTEGER;
    v_rejected              BOOLEAN;
    v_error_message         TEXT;
BEGIN
    INSERT INTO users (user_code, email, password_hash, full_name)
    VALUES (
        'CAPACITY-TEST',
        'capacity-user@example.test',
        '$test-only$not-a-real-password-hash',
        'Capacity Test User'
    )
    RETURNING user_id INTO v_user_id;

    INSERT INTO guests (full_name, email)
    VALUES ('Capacity Test Guest', 'capacity-guest@example.test')
    RETURNING guest_id INTO v_guest_id;

    INSERT INTO guests (full_name, email)
    VALUES ('Capacity Test Guest Two', 'capacity-guest-two@example.test')
    RETURNING guest_id INTO v_second_guest_id;

    INSERT INTO guests (full_name, email)
    VALUES ('Capacity Test Guest Three', 'capacity-guest-three@example.test')
    RETURNING guest_id INTO v_third_guest_id;

    v_property_id := create_property(
        ROW(
            'Capacity Test Property',
            100.000000,
            TRUE,
            'ROOM',
            NULL,
            NULL
        )::property_request,
        3
    );

    IF (SELECT max_guests FROM properties WHERE property_id = v_property_id) <> 3 THEN
        RAISE EXCEPTION 'Guest-aware property creation did not persist capacity';
    END IF;

    INSERT INTO properties (
        property_name, nightly_rate, property_type, max_guests, is_active
    ) VALUES (
        'Inactive Capacity Test Property', 100.000000, 'ROOM', 3, FALSE
    )
    RETURNING property_id INTO v_inactive_property_id;

    IF is_property_available(
        v_property_id, CURRENT_DATE + 100, CURRENT_DATE + 102, 1
    ) IS DISTINCT FROM TRUE
       OR is_property_available(
        v_property_id, CURRENT_DATE + 100, CURRENT_DATE + 102, 2
    ) IS DISTINCT FROM TRUE
       OR is_property_available(
        v_property_id, CURRENT_DATE + 100, CURRENT_DATE + 102, 3
    ) IS DISTINCT FROM TRUE
       OR is_property_available(
        v_property_id, CURRENT_DATE + 100, CURRENT_DATE + 102, 4
    ) IS DISTINCT FROM FALSE THEN
        RAISE EXCEPTION 'Free-date capacity checks are incorrect';
    END IF;

    IF is_property_available(
        v_inactive_property_id, CURRENT_DATE + 100, CURRENT_DATE + 102, 1
    ) IS DISTINCT FROM FALSE THEN
        RAISE EXCEPTION 'An inactive property was reported as available';
    END IF;

    FOREACH v_invalid_guests IN ARRAY ARRAY[NULL::INTEGER, 0, -1]
    LOOP
        v_rejected := FALSE;
        BEGIN
            PERFORM is_property_available(
                v_property_id,
                CURRENT_DATE + 100,
                CURRENT_DATE + 102,
                v_invalid_guests
            );
        EXCEPTION WHEN raise_exception THEN
            GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
            IF v_error_message <> 'Guest count must be greater than zero.' THEN
                RAISE;
            END IF;
            v_rejected := TRUE;
        END;

        IF NOT v_rejected THEN
            RAISE EXCEPTION 'Invalid guest count was accepted';
        END IF;
    END LOOP;

    FOREACH v_invalid_guests IN ARRAY ARRAY[NULL::INTEGER, 0, -1]
    LOOP
        v_rejected := FALSE;
        BEGIN
            PERFORM create_reservation(
                v_guest_id,
                v_property_id,
                CURRENT_DATE + 150,
                CURRENT_DATE + 151,
                v_invalid_guests,
                v_user_id
            );
        EXCEPTION WHEN raise_exception THEN
            GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
            IF v_error_message <> 'Guest count must be greater than zero.' THEN
                RAISE;
            END IF;
            v_rejected := TRUE;
        END;

        IF NOT v_rejected THEN
            RAISE EXCEPTION 'Creation accepted an invalid guest count';
        END IF;
    END LOOP;

    v_expected_total := calculate_booking_total(
        v_property_id, CURRENT_DATE + 200, CURRENT_DATE + 202
    );

    v_reservation_id := create_reservation(
        v_guest_id,
        v_property_id,
        CURRENT_DATE + 200,
        CURRENT_DATE + 202,
        2,
        v_user_id
    );

    IF NOT EXISTS (
        SELECT 1
        FROM reservations
        WHERE reservation_id = v_reservation_id
          AND guests_count = 2
          AND total_amount = v_expected_total
          AND status = 'PENDING'
    ) THEN
        RAISE EXCEPTION 'Guest-aware creation did not persist occupancy or pricing';
    END IF;

    IF is_property_available(
        v_property_id, CURRENT_DATE + 201, CURRENT_DATE + 203, 2
    ) IS DISTINCT FROM FALSE THEN
        RAISE EXCEPTION 'Occupied dates were reported as available';
    END IF;

    IF is_property_available(
        v_property_id, CURRENT_DATE + 202, CURRENT_DATE + 204, 3
    ) IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'A consecutive reservation was treated as overlapping';
    END IF;

    v_rejected := FALSE;
    BEGIN
        PERFORM create_reservation(
            v_second_guest_id,
            v_property_id,
            CURRENT_DATE + 300,
            CURRENT_DATE + 302,
            4,
            v_user_id
        );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> 'Property is not available for the selected dates or guest count.' THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;

    IF NOT v_rejected OR EXISTS (
        SELECT 1
        FROM reservations
        WHERE property_id = v_property_id
          AND check_in_date = CURRENT_DATE + 300
    ) THEN
        RAISE EXCEPTION 'Over-capacity creation was not rejected atomically';
    END IF;

    -- The paid path keeps the same property-level price and payment behavior.
    v_expected_total := calculate_booking_total(
        v_property_id, CURRENT_DATE + 400, CURRENT_DATE + 401
    );

    v_paid_reservation_id := create_reservation(
        v_second_guest_id,
        v_property_id,
        CURRENT_DATE + 400,
        CURRENT_DATE + 401,
        3,
        v_expected_total,
        'CAPACITY_TEST',
        v_user_id
    );

    IF NOT EXISTS (
        SELECT 1
        FROM reservations AS r
        JOIN payments AS p USING (reservation_id)
        WHERE r.reservation_id = v_paid_reservation_id
          AND r.guests_count = 3
          AND r.total_amount = v_expected_total
          AND r.status = 'CONFIRMED'
          AND p.payment_amount = v_expected_total
          AND p.status = 'PAID'
    ) THEN
        RAISE EXCEPTION 'Guest-aware paid creation changed pricing or payment behavior';
    END IF;

    -- The original five-argument call remains valid and stores one guest.
    v_legacy_reservation_id := create_reservation(
        v_third_guest_id,
        v_property_id,
        CURRENT_DATE + 500,
        CURRENT_DATE + 501,
        v_user_id
    );

    IF (SELECT guests_count FROM reservations
        WHERE reservation_id = v_legacy_reservation_id) <> 1 THEN
        RAISE EXCEPTION 'Legacy creation did not use one guest';
    END IF;

    -- CANCELLED rows do not block dates.
    UPDATE reservations
    SET status = 'CANCELLED'
    WHERE reservation_id = v_legacy_reservation_id;

    IF is_property_available(
        v_property_id, CURRENT_DATE + 500, CURRENT_DATE + 501, 3
    ) IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'A cancelled reservation blocked availability';
    END IF;

    -- Direct writes cannot bypass capacity.
    v_rejected := FALSE;
    BEGIN
        INSERT INTO reservations (
            guest_id, property_id, guests_count, created_by_user_id,
            check_in_date, check_out_date, status, total_amount
        ) VALUES (
            v_third_guest_id, v_property_id, 4, v_user_id,
            CURRENT_DATE + 600, CURRENT_DATE + 601, 'PENDING', 100.000000
        );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message <> format(
            'Guest count 4 exceeds maximum capacity 3 for property %s.',
            v_property_id
        ) THEN
            RAISE;
        END IF;
        v_rejected := TRUE;
    END;

    IF NOT v_rejected THEN
        RAISE EXCEPTION 'A direct over-capacity write was accepted';
    END IF;

    BEGIN
        UPDATE properties SET max_guests = 0 WHERE property_id = v_property_id;
        RAISE EXCEPTION 'A non-positive property capacity was accepted';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    BEGIN
        UPDATE reservations
        SET guests_count = 0
        WHERE reservation_id = v_reservation_id;
        RAISE EXCEPTION 'A non-positive reservation guest count was accepted';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    IF to_regprocedure(
        'is_property_available(bigint,date,date)'
    ) IS NULL
       OR to_regprocedure(
        'is_property_available(bigint,date,date,integer)'
    ) IS NULL
       OR to_regprocedure(
        'create_reservation(bigint,bigint,date,date,bigint)'
    ) IS NULL
       OR to_regprocedure(
        'create_reservation(bigint,bigint,date,date,integer,bigint)'
    ) IS NULL THEN
        RAISE EXCEPTION 'Required compatibility or guest-aware overload is missing';
    END IF;
END;
$$;

ROLLBACK;
