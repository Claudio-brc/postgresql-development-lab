-- Apply after 001_add_property_type.sql.

BEGIN;

CREATE SEQUENCE IF NOT EXISTS property_code_number_seq;

ALTER TABLE properties
    ADD COLUMN IF NOT EXISTS property_code VARCHAR(10);

CREATE OR REPLACE FUNCTION set_property_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_prefix VARCHAR(3);
    v_number BIGINT;
BEGIN
    IF NEW.property_code IS NULL OR BTRIM(NEW.property_code) = '' THEN
        v_prefix := CASE NEW.property_type
            WHEN 'CABIN' THEN 'CAB'
            WHEN 'APARTMENT' THEN 'APT'
            WHEN 'ROOM' THEN 'ROM'
        END;

        IF v_prefix IS NULL THEN
            RAISE EXCEPTION 'Invalid property type: %', NEW.property_type
                USING ERRCODE = '23514';
        END IF;

        LOOP
            v_number := nextval('property_code_number_seq');

            IF v_number > 9999 THEN
                RAISE EXCEPTION 'Property code sequence exhausted at %', v_number;
            END IF;

            NEW.property_code := v_prefix || '-' || LPAD(v_number::TEXT, 4, '0');
            EXIT WHEN NOT EXISTS (
                SELECT 1
                FROM properties
                WHERE property_code = NEW.property_code
                  AND property_id <> NEW.property_id
            );
        END LOOP;
    ELSE
        NEW.property_code := UPPER(BTRIM(NEW.property_code));
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_properties_set_property_code ON properties;

CREATE TRIGGER trg_properties_set_property_code
BEFORE INSERT OR UPDATE OF property_code, property_type ON properties
FOR EACH ROW
EXECUTE FUNCTION set_property_code();

UPDATE properties
SET property_code = NULL
WHERE property_code IS NULL OR BTRIM(property_code) = '';

ALTER TABLE properties
    ALTER COLUMN property_code SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'properties'::regclass
          AND conname = 'properties_property_code_not_empty_check'
    ) THEN
        ALTER TABLE properties
            ADD CONSTRAINT properties_property_code_not_empty_check
            CHECK (property_code <> '');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'properties'::regclass
          AND conname = 'properties_property_code_format_check'
    ) THEN
        ALTER TABLE properties
            ADD CONSTRAINT properties_property_code_format_check
            CHECK (property_code ~ '^[A-Z]{3}-[0-9]{4}$');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'properties'::regclass
          AND conname = 'properties_property_code_key'
    ) THEN
        ALTER TABLE properties
            ADD CONSTRAINT properties_property_code_key UNIQUE (property_code);
    END IF;
END;
$$;

COMMIT;
