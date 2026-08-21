-- Apply after 004_add_guest_is_active.sql.
-- Historical guests keep both document fields NULL.

BEGIN;

ALTER TABLE guests
    ADD COLUMN IF NOT EXISTS document_type VARCHAR(30),
    ADD COLUMN IF NOT EXISTS document_number VARCHAR(50);

CREATE OR REPLACE FUNCTION normalize_guest_document()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.document_type := NULLIF(UPPER(BTRIM(NEW.document_type)), '');
    NEW.document_number := NULLIF(BTRIM(NEW.document_number), '');
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guests_normalize_document ON guests;

CREATE TRIGGER trg_guests_normalize_document
BEFORE INSERT OR UPDATE OF document_type, document_number ON guests
FOR EACH ROW
EXECUTE FUNCTION normalize_guest_document();

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'guests'::REGCLASS
          AND conname = 'chk_guests_document_pair'
    ) THEN
        ALTER TABLE guests
            ADD CONSTRAINT chk_guests_document_pair
            CHECK (
                (document_type IS NULL AND document_number IS NULL)
                OR
                (document_type IS NOT NULL AND document_number IS NOT NULL)
            );
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'guests'::REGCLASS
          AND conname = 'uq_guests_document'
    ) THEN
        ALTER TABLE guests
            ADD CONSTRAINT uq_guests_document
            UNIQUE (document_type, document_number);
    END IF;
END;
$$;

COMMIT;
