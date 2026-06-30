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
