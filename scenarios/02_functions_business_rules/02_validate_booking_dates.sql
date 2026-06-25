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
    RAISE EXCEPTION 'Check in date can´t be NULL.';
  end if;   

  if p_check_out_date is null then
    RAISE EXCEPTION 'Check out date can´t be NULL.';
  end if;   

  if p_check_out_date < p_check_in_date then
    RAISE EXCEPTION 'Check in date can´t be after check out date.';
  end if;   

  if (p_check_out_date - p_check_in_date) < 1  then
    RAISE EXCEPTION 'The stay can´t be less than a night.';
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
