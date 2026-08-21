-- Run after installing the consolidated Development Lab schema.
-- This example rolls back its test data after verifying document rules.

BEGIN;

DO $$
DECLARE
    v_historical_guest_id BIGINT;
    v_dni_guest_id        BIGINT;
    v_passport_guest_id   BIGINT;
BEGIN
    INSERT INTO guests (full_name, email)
    VALUES ('Historical Guest Example', 'historical-document-example@example.com')
    RETURNING guest_id INTO v_historical_guest_id;

    IF NOT EXISTS (
        SELECT 1
        FROM guests
        WHERE guest_id = v_historical_guest_id
          AND document_type IS NULL
          AND document_number IS NULL
    ) THEN
        RAISE EXCEPTION 'A guest without document data must remain valid';
    END IF;

    INSERT INTO guests (full_name, email, document_type, document_number)
    VALUES (
        'DNI Guest Example',
        'dni-document-example@example.com',
        '  dni  ',
        '  12345678  '
    )
    RETURNING guest_id INTO v_dni_guest_id;

    IF NOT EXISTS (
        SELECT 1
        FROM guests
        WHERE guest_id = v_dni_guest_id
          AND document_type = 'DNI'
          AND document_number = '12345678'
    ) THEN
        RAISE EXCEPTION 'DNI values must be trimmed and the type uppercased';
    END IF;

    INSERT INTO guests (full_name, email, document_type, document_number)
    VALUES (
        'Passport Guest Example',
        'passport-document-example@example.com',
        'PASSPORT',
        'AB-123456'
    )
    RETURNING guest_id INTO v_passport_guest_id;

    BEGIN
        INSERT INTO guests (full_name, email, document_type)
        VALUES ('Incomplete Document Example', 'incomplete-type@example.com', 'DNI');
        RAISE EXCEPTION 'An incomplete document pair was accepted';
    EXCEPTION
        WHEN check_violation THEN NULL;
    END;

    BEGIN
        INSERT INTO guests (full_name, email, document_number)
        VALUES ('Incomplete Number Example', 'incomplete-number@example.com', '12345678');
        RAISE EXCEPTION 'An incomplete document pair was accepted';
    EXCEPTION
        WHEN check_violation THEN NULL;
    END;

    BEGIN
        INSERT INTO guests (full_name, email, document_type, document_number)
        VALUES ('Duplicate DNI Example', 'duplicate-dni@example.com', 'dni', '12345678');
        RAISE EXCEPTION 'A duplicate document pair was accepted';
    EXCEPTION
        WHEN unique_violation THEN NULL;
    END;

    INSERT INTO guests (full_name, email, document_type, document_number)
    VALUES (
        'Same Number Different Type Example',
        'same-number-different-type@example.com',
        'ID_CARD',
        '12345678'
    );

    IF NOT EXISTS (
        SELECT 1
        FROM guests
        WHERE guest_id = v_passport_guest_id
          AND document_type = 'PASSPORT'
          AND document_number = 'AB-123456'
    ) THEN
        RAISE EXCEPTION 'The alphanumeric passport was not preserved';
    END IF;
END;
$$;

ROLLBACK;
