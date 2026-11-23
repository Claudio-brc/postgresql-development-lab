-- Apply after 012_reservation_checkout_guard.sql with psql.
-- Historical capacity and occupancy are unknown, so existing rows receive the
-- conservative compatibility value 1. That value is not verified history.

BEGIN;

ALTER TABLE properties
    ADD COLUMN IF NOT EXISTS max_guests INTEGER DEFAULT 1;

ALTER TABLE reservations
    ADD COLUMN IF NOT EXISTS guests_count INTEGER DEFAULT 1;

UPDATE properties
SET max_guests = 1
WHERE max_guests IS NULL;

UPDATE reservations
SET guests_count = 1
WHERE guests_count IS NULL;

ALTER TABLE properties
    ALTER COLUMN max_guests SET DEFAULT 1,
    ALTER COLUMN max_guests SET NOT NULL;

ALTER TABLE reservations
    ALTER COLUMN guests_count SET DEFAULT 1,
    ALTER COLUMN guests_count SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'properties'::REGCLASS
          AND conname = 'chk_properties_max_guests'
    ) THEN
        ALTER TABLE properties
            ADD CONSTRAINT chk_properties_max_guests
            CHECK (max_guests > 0);
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'reservations'::REGCLASS
          AND conname = 'chk_reservations_guests_count'
    ) THEN
        ALTER TABLE reservations
            ADD CONSTRAINT chk_reservations_guests_count
            CHECK (guests_count > 0);
    END IF;
END;
$$;

-- Reuse canonical sources so upgraded and clean-installed databases expose
-- the same overload set. These are psql meta-commands, not ordinary SQL.
\ir ../../scenarios/09_property_capacity/01_is_property_available.sql
\ir ../../scenarios/09_property_capacity/02_enforce_reservation_capacity.sql
\ir ../../scenarios/09_property_capacity/03_create_property.sql
\ir ../../scenarios/09_property_capacity/04_initialize_reservation.sql
\ir ../../scenarios/09_property_capacity/05_create_reservation.sql

COMMIT;
