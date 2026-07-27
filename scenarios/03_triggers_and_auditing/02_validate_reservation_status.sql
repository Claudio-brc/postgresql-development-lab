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