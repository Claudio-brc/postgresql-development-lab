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

	

  PERFORM confirm_reservation(v_reservation_id);

  RETURN v_reservation_id;

END;
$BODY$;

ALTER FUNCTION public.process_booking(bigint, bigint, date, date, numeric, varchar)
    OWNER TO postgres;

	