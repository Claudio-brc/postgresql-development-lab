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

  RETURN calculate_weekly_discount(v_total_base, p_check_out - p_check_in);

END;
$BODY$;

ALTER FUNCTION public.calculate_booking_total(bigint, date, date)
    OWNER TO postgres;
