-- Run after installing the consolidated Development Lab schema.
-- Every change made by this verification is rolled back.

BEGIN;

DO $$
DECLARE
    v_calvarez_user_id BIGINT;
    v_test_user_id     BIGINT;
    v_guest_id         BIGINT;
    v_property_id      BIGINT;
    v_reservation_id   BIGINT;
    v_invalid_code     TEXT;
BEGIN
    SELECT user_id
    INTO STRICT v_calvarez_user_id
    FROM users
    WHERE user_code = 'CALVAREZ'
      AND full_name = 'Claudio Alvarez'
      AND email = 'calvarez.brc@gmail.com'
      AND is_active = TRUE;

    IF v_calvarez_user_id IS NULL THEN
        RAISE EXCEPTION 'CALVAREZ must have an automatically generated user_id';
    END IF;

    INSERT INTO users (
        user_code,
        email,
        password_hash,
        full_name
    )
    VALUES (
        'TEST-USER2',
        'test-user2@example.test',
        '$development-only$already-processed-test-value',
        'Application User Example'
    )
    RETURNING user_id INTO v_test_user_id;

    IF v_test_user_id IS NULL THEN
        RAISE EXCEPTION 'user_id was not generated automatically';
    END IF;

    IF NOT (SELECT is_active FROM users WHERE user_id = v_test_user_id) THEN
        RAISE EXCEPTION 'A new application user must be active by default';
    END IF;

    IF (SELECT password_hash FROM users WHERE user_id = v_test_user_id)
        <> '$development-only$already-processed-test-value' THEN
        RAISE EXCEPTION 'PostgreSQL must preserve the supplied password hash';
    END IF;

    BEGIN
        INSERT INTO users (email, password_hash, full_name)
        VALUES (
            'missing-code@example.test',
            '$development-only$test-value',
            'Missing Code Example'
        );
        RAISE EXCEPTION 'A user without user_code was accepted';
    EXCEPTION
        WHEN not_null_violation THEN NULL;
    END;

    BEGIN
        INSERT INTO users (user_code, email, password_hash, full_name)
        VALUES (
            'TEST-USER2',
            'duplicate-code@example.test',
            '$development-only$test-value',
            'Duplicate Code Example'
        );
        RAISE EXCEPTION 'A duplicate user_code was accepted';
    EXCEPTION
        WHEN unique_violation THEN NULL;
    END;

    BEGIN
        INSERT INTO users (user_code, email, password_hash, full_name)
        VALUES (
            'UNIQUE-EMAIL',
            'test-user2@example.test',
            '$development-only$test-value',
            'Duplicate Email Example'
        );
        RAISE EXCEPTION 'A duplicate email was accepted';
    EXCEPTION
        WHEN unique_violation THEN NULL;
    END;

    FOREACH v_invalid_code IN ARRAY ARRAY[
        'mbriada',
        'Marcelo Briada',
        'MBRIADA_1',
        '-MBRIADA',
        'MBRIADA-'
    ]
    LOOP
        BEGIN
            INSERT INTO users (user_code, email, password_hash, full_name)
            VALUES (
                v_invalid_code,
                'invalid-' || md5(v_invalid_code) || '@example.test',
                '$development-only$test-value',
                'Invalid Code Example'
            );
            RAISE EXCEPTION 'Invalid user_code % was accepted', v_invalid_code;
        EXCEPTION
            WHEN check_violation THEN NULL;
        END;
    END LOOP;

    INSERT INTO guests (full_name, email)
    VALUES ('Reservation Guest Example', 'reservation-guest@example.test')
    RETURNING guest_id INTO v_guest_id;

    SELECT property_id
    INTO v_property_id
    FROM properties
    ORDER BY property_id
    LIMIT 1;

    v_reservation_id := create_reservation(
        v_guest_id,
        v_property_id,
        DATE '2099-02-01',
        DATE '2099-02-02',
        v_calvarez_user_id
    );

    IF NOT EXISTS (
        SELECT 1
        FROM reservations AS r
        JOIN guests AS g ON g.guest_id = r.guest_id
        JOIN users AS u ON u.user_id = r.created_by_user_id
        WHERE r.reservation_id = v_reservation_id
          AND g.full_name = 'Reservation Guest Example'
          AND u.user_code = 'CALVAREZ'
    ) THEN
        RAISE EXCEPTION 'Guest and application user relationships were not preserved';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM reservations
        WHERE created_by_user_id IS NULL
    ) THEN
        RAISE EXCEPTION 'Every reservation must have an application user creator';
    END IF;

    BEGIN
        INSERT INTO reservations (
            guest_id,
            property_id,
            check_in_date,
            check_out_date
        )
        VALUES (
            v_guest_id,
            v_property_id,
            DATE '2099-03-01',
            DATE '2099-03-02'
        );
        RAISE EXCEPTION 'A reservation without created_by_user_id was accepted';
    EXCEPTION
        WHEN not_null_violation THEN NULL;
    END;

    BEGIN
        PERFORM create_reservation(
            v_guest_id,
            v_property_id,
            DATE '2099-04-01',
            DATE '2099-04-02'
        );
        RAISE EXCEPTION 'The obsolete create_reservation signature still exists';
    EXCEPTION
        WHEN undefined_function THEN NULL;
    END;

    BEGIN
        PERFORM create_reservation(
            v_guest_id,
            v_property_id,
            DATE '2099-05-01',
            DATE '2099-05-02',
            -1
        );
        RAISE EXCEPTION 'A reservation with an invalid user_id was accepted';
    EXCEPTION
        WHEN foreign_key_violation THEN NULL;
    END;
END;
$$;

ROLLBACK;
