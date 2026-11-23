-- Table checks reject non-positive values. This trigger also protects direct
-- reservation writes from exceeding the property's current capacity.
CREATE OR REPLACE FUNCTION enforce_reservation_capacity()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_max_guests INTEGER;
BEGIN
    SELECT p.max_guests
    INTO v_max_guests
    FROM properties AS p
    WHERE p.property_id = NEW.property_id
    FOR SHARE;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    IF NEW.guests_count > v_max_guests THEN
        RAISE EXCEPTION
            'Guest count % exceeds maximum capacity % for property %.',
            NEW.guests_count,
            v_max_guests,
            NEW.property_id;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_reservations_enforce_capacity ON reservations;

CREATE TRIGGER trg_reservations_enforce_capacity
BEFORE INSERT OR UPDATE OF property_id, guests_count ON reservations
FOR EACH ROW
EXECUTE FUNCTION enforce_reservation_capacity();
