-- Run after installing the consolidated Development Lab schema.
-- Every statement is rolled back so this verification does not retain data.

BEGIN;

-- Automatic generation and every allowed property type.
INSERT INTO properties (property_name, nightly_rate, property_type)
VALUES
    ('Code Test Cabin', 100.00, 'CABIN'),
    ('Code Test Apartment', 100.00, 'APARTMENT'),
    ('Code Test Room', 100.00, 'ROOM')
RETURNING property_type, property_code;

-- Empty input also generates a code; the sequence number is global.
INSERT INTO properties (property_name, nightly_rate, property_type, property_code)
VALUES ('Empty Code Test', 100.00, 'ROOM', '   ')
RETURNING property_code;

-- Manual codes are normalized and remain editable.
INSERT INTO properties (property_name, nightly_rate, property_type, property_code)
VALUES ('Manual Code Test', 100.00, 'CABIN', 'tst-9000')
RETURNING property_code;

UPDATE properties
SET property_code = 'edt-9001'
WHERE property_code = 'TST-9000'
RETURNING property_code;

-- Each block must report the expected constraint violation and continue.
DO $$
BEGIN
    BEGIN
        INSERT INTO properties (property_name, nightly_rate, property_type)
        VALUES ('Invalid Type Test', 100.00, 'HOUSE');
        RAISE EXCEPTION 'Expected invalid property_type to be rejected';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'Invalid property type rejected as expected';
    END;

    BEGIN
        INSERT INTO properties (property_name, nightly_rate, property_type, property_code)
        VALUES ('Duplicate Code Test', 100.00, 'ROOM', 'EDT-9001');
        RAISE EXCEPTION 'Expected duplicate property_code to be rejected';
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE 'Duplicate property code rejected as expected';
    END;

    BEGIN
        INSERT INTO properties (property_name, nightly_rate, property_type, property_code)
        VALUES ('Invalid Format Test', 100.00, 'ROOM', 'INVALID');
        RAISE EXCEPTION 'Expected invalid property_code format to be rejected';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'Invalid property code format rejected as expected';
    END;
END;
$$;

ROLLBACK;
