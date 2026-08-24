-- Run after installing the consolidated Development Lab schema.
-- This example rolls back its test data after verifying guest soft deletion.

BEGIN;

DO $$
DECLARE
    v_guest_id       BIGINT;
    v_property_id    BIGINT;
    v_reservation_id BIGINT;
    v_user_id        BIGINT;
BEGIN
    INSERT INTO guests (full_name, email)
    VALUES ('Soft Delete Example', 'soft-delete-example@example.com')
    RETURNING guest_id INTO v_guest_id;

    IF NOT (SELECT is_active FROM guests WHERE guest_id = v_guest_id) THEN
        RAISE EXCEPTION 'A newly created guest must be active by default';
    END IF;

    SELECT property_id
    INTO v_property_id
    FROM properties
    ORDER BY property_id
    LIMIT 1;

    IF v_property_id IS NULL THEN
        RAISE EXCEPTION 'The example requires at least one seeded property';
    END IF;

    SELECT user_id
    INTO v_user_id
    FROM users
    WHERE user_code = 'CALVAREZ';

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'The example requires the CALVAREZ application user';
    END IF;

    INSERT INTO reservations (
        guest_id,
        property_id,
        check_in_date,
        check_out_date,
        created_by_user_id
    )
    VALUES (
        v_guest_id,
        v_property_id,
        DATE '2099-01-01',
        DATE '2099-01-02',
        v_user_id
    )
    RETURNING reservation_id INTO v_reservation_id;

    UPDATE guests
    SET is_active = FALSE
    WHERE guest_id = v_guest_id;

    IF NOT EXISTS (
        SELECT 1
        FROM guests
        WHERE guest_id = v_guest_id
          AND is_active = FALSE
    ) THEN
        RAISE EXCEPTION 'The inactive guest row must continue to exist';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM reservations AS r
        JOIN guests AS g ON g.guest_id = r.guest_id
        WHERE r.reservation_id = v_reservation_id
          AND g.guest_id = v_guest_id
          AND g.is_active = FALSE
    ) THEN
        RAISE EXCEPTION 'The historical reservation relationship must remain valid';
    END IF;
END;
$$;

ROLLBACK;
