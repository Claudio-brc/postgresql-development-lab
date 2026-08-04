-- Apply this script to an existing Development Lab database.
--
-- Existing rows do not contain enough information to infer a reliable type.
-- They receive ROOM as a documented transitional value and should be reviewed
-- by the database owner after the upgrade.

BEGIN;

ALTER TABLE properties
    ADD COLUMN IF NOT EXISTS property_type VARCHAR(20);

UPDATE properties
SET property_type = 'ROOM'
WHERE property_type IS NULL;

ALTER TABLE properties
    ALTER COLUMN property_type SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'properties'::regclass
          AND conname = 'properties_property_type_check'
    ) THEN
        ALTER TABLE properties
            ADD CONSTRAINT properties_property_type_check
            CHECK (property_type IN ('CABIN', 'APARTMENT', 'ROOM'));
    END IF;
END;
$$;

COMMIT;

-- Review the transitional classification after the upgrade:
-- SELECT property_id, property_name, property_type
-- FROM properties
-- ORDER BY property_id;
