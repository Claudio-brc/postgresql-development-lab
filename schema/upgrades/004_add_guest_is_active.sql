-- Apply after 003_update_property_creation.sql.
-- Existing guests remain active; soft deletion is performed with UPDATE.

BEGIN;

ALTER TABLE guests
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

COMMIT;
