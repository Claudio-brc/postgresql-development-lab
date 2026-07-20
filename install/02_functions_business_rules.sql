------------------------------------------------------------
-- Source: 01_calculate_booking_discount.sql
------------------------------------------------------------

-- FUNCTION: public.calculate_booking_discount(numeric, integer, date)

-- DROP FUNCTION IF EXISTS public.calculate_booking_discount(numeric, integer, date);

CREATE OR REPLACE FUNCTION public.calculate_booking_discount(
	p_total_amount NUMERIC,
    p_nights INTEGER,
    p_check_in DATE)
    RETURNS numeric
    LANGUAGE 'plpgsql'
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_discount_percent NUMERIC;
BEGIN

  IF p_check_in IS NULL THEN
    RAISE EXCEPTION 'Check-in date cannot be NULL.';
  END IF;

  IF COALESCE(p_total_amount, 0) <= 0 THEN
    RAISE EXCEPTION 'Amount incorrect.';
  END IF;

  IF COALESCE(p_nights, 0) <= 0 THEN
    RAISE EXCEPTION 'Nights quantity incorrect.';
  END IF;

  SELECT discount_percent
    INTO v_discount_percent
    FROM discounts
   WHERE is_active = TRUE
     AND (
         (
            discount_type = 'STAY_LENGTH'
            AND minimum_nights <= p_nights
         )
         OR
         (
            discount_type = 'DATE_RANGE'
            AND p_check_in BETWEEN valid_from AND valid_to
         ))
   ORDER BY discount_percent DESC
   LIMIT 1;

   IF v_discount_percent IS NULL THEN
     RETURN p_total_amount;
   END IF;

   RETURN p_total_amount * (1 - v_discount_percent / 100);
  
END;
$BODY$;

ALTER FUNCTION public.calculate_booking_discount(numeric, integer, date)
    OWNER TO postgres;



------------------------------------------------------------
-- Source: 02_validate_booking_dates.sql
------------------------------------------------------------

-- FUNCTION: public.validate_booking_dates(date, date)

-- DROP FUNCTION IF EXISTS public.validate_booking_dates(date, date);

CREATE OR REPLACE FUNCTION public.validate_booking_dates(
	p_check_in_date date,
	p_check_out_date date)
    RETURNS boolean
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE v_max_stay INTEGER;
BEGIN

  if p_check_in_date is null then
    RAISE EXCEPTION 'Check in date canÂ´t be NULL.';
  end if;   

  if p_check_out_date is null then
    RAISE EXCEPTION 'Check out date canÂ´t be NULL.';
  end if;   

  if p_check_out_date < p_check_in_date then
    RAISE EXCEPTION 'Check in date canÂ´t be after check out date.';
  end if;   

  if (p_check_out_date - p_check_in_date) < 1  then
    RAISE EXCEPTION 'The stay canÂ´t be less than a night.';
  end if;   

  v_max_stay := get_setting('max_stay_nights')::INTEGER;

  if v_max_stay < (p_check_out_date - p_check_in_date)   then
    RAISE EXCEPTION 'The maximum stay is 30 nights.';
  end if;     
  
  return true;
END;
$BODY$;

ALTER FUNCTION public.validate_booking_dates(date, date)
    OWNER TO postgres;



------------------------------------------------------------
-- Source: 03_can_guest_book.sql
------------------------------------------------------------

-- FUNCTION: public.can_guest_book(bigint)

-- DROP FUNCTION IF EXISTS public.can_guest_book(bigint);

CREATE OR REPLACE FUNCTION public.can_guest_book(
	p_guest_id bigint)
    RETURNS boolean
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
  v_guest_exists BIGINT;
	v_reservation_count INT;
	v_max_pending INTEGER;

BEGIN

  SELECT g.guest_id         
    INTO v_guest_exists
    FROM guests as g 
   WHERE g.guest_id = p_guest_id;

  if v_guest_exists is NULL then
    RAISE EXCEPTION 'Guest not found.';
  end if; 

  Select count(*)
    INTO  v_reservation_count
    from reservations r
	where r.guest_id = p_guest_id
	  and r.status = 'PENDING';

  v_max_pending := get_setting('max_pending_reservations')::INTEGER;	  

  if v_max_pending <= v_reservation_count then
    RAISE EXCEPTION 'Guest has reached the maximum number of pending reservations.';
  end if;

  return true;
END;
$BODY$;

ALTER FUNCTION public.can_guest_book(bigint)
    OWNER TO postgres;


------------------------------------------------------------
-- Source: 04_calculate_booking_total.sql
------------------------------------------------------------

-- FUNCTION: public.calculate_booking_total(bigint, date, date)

-- DROP FUNCTION IF EXISTS public.calculate_booking_total(bigint, date, date);

CREATE OR REPLACE FUNCTION public.calculate_booking_total(
	p_property_id bigint,
	p_check_in date,
	p_check_out date)
    RETURNS numeric
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
  v_total_base NUMERIC;
BEGIN
   
  PERFORM  validate_booking_dates(p_check_in, p_check_out);

  v_total_base := calculate_stay_cost(p_property_id, p_check_in, p_check_out);

  RETURN calculate_booking_discount(v_total_base, p_check_out - p_check_in, p_check_in);


END;
$BODY$;

ALTER FUNCTION public.calculate_booking_total(bigint, date, date)
    OWNER TO postgres;



------------------------------------------------------------
-- Source: 05_create_reservation.sql
------------------------------------------------------------

-- FUNCTION: public.create_reservation(bigint, bigint, date, date)

-- DROP FUNCTION IF EXISTS public.create_reservation(bigint, bigint, date, date);

CREATE OR REPLACE FUNCTION public.create_reservation(
    p_guest_id BIGINT,
    p_property_id BIGINT,
    p_check_in DATE,
    p_check_out DATE
)
RETURNS BIGINT
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE 
v_total_amount NUMERIC;
v_reservation_id BIGINT;
v_is_available BOOLEAN;
BEGIN

  PERFORM validate_booking_dates(
      p_check_in,
      p_check_out
   );

  v_is_available := is_property_available(
    p_property_id,
    p_check_in,
    p_check_out); 

	
  if not v_is_available then
	RAISE EXCEPTION 'Property is not available for the selected dates.';
  end if;	

  PERFORM can_guest_book(
    p_guest_id);

  v_total_amount := calculate_booking_total(
    p_property_id,
    p_check_in,
    p_check_out);	

  INSERT INTO reservations
  (
    guest_id,
    property_id,
    check_in_date,
    check_out_date,
    total_amount,
    status
  )
  VALUES  
  (
    p_guest_id,
    p_property_id,
    p_check_in,
    p_check_out,
    v_total_amount,
    'PENDING'
  )
  RETURNING reservation_id
  INTO v_reservation_id;	


  
  return v_reservation_id;
END;
$BODY$;

ALTER FUNCTION public.create_reservation(bigint, bigint, date, date)
    OWNER TO postgres;



------------------------------------------------------------
-- Source: 06_process_booking.sql
------------------------------------------------------------

-- FUNCTION: public.process_booking(bigint, bigint, date, date)

-- DROP FUNCTION IF EXISTS public.process_booking(bigint, bigint, date, date);

CREATE OR REPLACE FUNCTION public.process_booking(
p_guest_id        BIGINT,
p_property_id     BIGINT,
p_check_in        DATE,
p_check_out       DATE,
p_payment_amount  NUMERIC(12,2),
p_payment_method  VARCHAR(30)
)



RETURNS BIGINT
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE 
v_reservation_id BIGINT;
v_total_amount NUMERIC;
BEGIN

  IF COALESCE(p_payment_amount, 0) <= 0 THEN
    RAISE EXCEPTION
      'Payment amount must be greater than zero.';
  END IF;

  IF p_payment_method IS NULL THEN
    RAISE EXCEPTION
      'Payment method cannot be NULL.';
  END IF;

  v_reservation_id :=
  create_reservation(
    p_guest_id,
    p_property_id,
    p_check_in,
    p_check_out);

  SELECT total_amount
    INTO v_total_amount
    FROM reservations
   WHERE reservation_id = v_reservation_id;

  IF ABS(v_total_amount - p_payment_amount) >= 0.01 THEN	
      RAISE EXCEPTION
        'Payment amount does not match the reservation total.';
  END IF;

  INSERT INTO public.payments(
	 reservation_id, payment_amount, payment_method, status, payment_date)
	VALUES ( v_reservation_id, p_payment_amount, p_payment_method,'PAID', CURRENT_DATE);

	
  UPDATE RESERVATIONS R
     SET status = 'CONFIRMED' 
	WHERE R.reservation_id = v_reservation_id;


  RETURN v_reservation_id;

END;
$BODY$;

ALTER FUNCTION public.process_booking(bigint, bigint, date, date, numeric, varchar)
    OWNER TO postgres;

------------------------------------------------------------
-- Source: 07_confirm_reservation.sql
------------------------------------------------------------

-- FUNCTION: public.confirm_reservation(bigint)

-- DROP FUNCTION IF EXISTS public.confirm_reservation(bigint);



CREATE OR REPLACE FUNCTION public.confirm_reservation(
    p_reservation_id BIGINT
)
RETURNS VOID
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE 
v_status VARCHAR(20);

BEGIN

  SELECT status
    INTO v_status
    FROM reservations r
   WHERE reservation_id = p_reservation_id;

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
  END IF;
   
  IF v_status <> 'PENDING' THEN
    RAISE EXCEPTION 'Reservation must be PENDING.';
  END IF;

  UPDATE reservations
     SET status = 'CONFIRMED'
   WHERE reservation_id = p_reservation_id;


END;
$BODY$;    

ALTER FUNCTION public.confirm_reservation(bigint)
    OWNER TO postgres;


------------------------------------------------------------
-- Source: 08_cancel_reservation.sql
------------------------------------------------------------

-- FUNCTION: public.cancel_reservation(bigint)

-- DROP FUNCTION IF EXISTS public.cancel_reservation(bigint);

CREATE OR REPLACE FUNCTION public.cancel_reservation(
    p_reservation_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
BEGIN

    SELECT status
      INTO v_status
      FROM reservations
     WHERE reservation_id = p_reservation_id;

    IF v_status IS NULL THEN
        RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE EXCEPTION 'Reservation is already cancelled.';
    END IF;

    UPDATE reservations
       SET status = 'CANCELLED'
     WHERE reservation_id = p_reservation_id;

END;
$$;    


ALTER FUNCTION public.cancel_reservation(bigint)
    OWNER TO postgres;

	



