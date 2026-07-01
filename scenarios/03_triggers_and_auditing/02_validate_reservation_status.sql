CREATE OR REPLACE FUNCTION validate_reservation_status()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.status = 'CONFIRMED' and  NEW.status = 'PENDING' ) THEN
	  RAISE EXCEPTION
    'Invalid reservation status transition from % to %.',
     OLD.status,
     NEW.status;
	  END IF;

    IF (OLD.status = 'CANCELLED' and  NEW.status = 'PENDING' ) THEN
      RAISE EXCEPTION
      'Invalid reservation status transition from % to %.',
      OLD.status,
      NEW.status;
	  END IF;	

    IF (OLD.status = 'CANCELLED' and  NEW.status = 'CONFIRMED' ) THEN
      RAISE EXCEPTION
      'Invalid reservation status transition from % to %.',
      OLD.status,
      NEW.status;
	  END IF;	

	  RETURN NEW;
	
END;
$$ LANGUAGE plpgsql;


CREATE or replace TRIGGER trg_reservations_validate_status
BEFORE UPDATE ON reservations
FOR EACH ROW
EXECUTE FUNCTION validate_reservation_status();

