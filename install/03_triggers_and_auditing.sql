------------------------------------------------------------
-- PostgreSQL Development Lab
-- Scenario: 03_triggers_and_auditing
--
-- AUTO-GENERATED FILE
-- DO NOT EDIT MANUALLY
------------------------------------------------------------

------------------------------------------------------------
-- Source: 01_update_updated_at_trigger.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_discounts_update_updated_at
BEFORE UPDATE ON discounts
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();

CREATE OR REPLACE TRIGGER trg_guests_update_updated_at
BEFORE UPDATE ON guests
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();

CREATE OR REPLACE TRIGGER trg_properties_update_updated_at
BEFORE UPDATE ON properties
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();

CREATE OR REPLACE TRIGGER trg_reservations_update_updated_at
BEFORE UPDATE ON reservations
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();

CREATE OR REPLACE TRIGGER trg_payments_update_updated_at
BEFORE UPDATE ON payments
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();


------------------------------------------------------------
-- Source: 02_validate_reservation_status.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION validate_reservation_status()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF (OLD.status = 'CONFIRMED' AND NEW.status = 'PENDING') THEN
        RAISE EXCEPTION
            'Invalid reservation status transition from % to %.',
            OLD.status,
            NEW.status;
    END IF;

    IF (OLD.status = 'CANCELLED' AND NEW.status = 'PENDING') THEN
        RAISE EXCEPTION
            'Invalid reservation status transition from % to %.',
            OLD.status,
            NEW.status;
    END IF;

    IF (OLD.status = 'CANCELLED' AND NEW.status = 'CONFIRMED') THEN
        RAISE EXCEPTION
            'Invalid reservation status transition from % to %.',
            OLD.status,
            NEW.status;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_reservations_validate_status
BEFORE UPDATE ON reservations
FOR EACH ROW
EXECUTE FUNCTION validate_reservation_status();


------------------------------------------------------------
-- Source: 03_log_reservation_audit.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION log_reservation_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO reservation_status_audit (
            reservation_id,
            old_status,
            new_status
        )
        VALUES (
            NEW.reservation_id,
            OLD.status,
            NEW.status
        );
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_reservation_audit
AFTER UPDATE OF status ON reservations
FOR EACH ROW
EXECUTE FUNCTION log_reservation_status_change();



