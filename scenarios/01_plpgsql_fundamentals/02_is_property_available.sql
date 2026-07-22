-- FUNCTION: public.is_property_available(bigint, date, date)

-- DROP FUNCTION IF EXISTS public.is_property_available(bigint, date, date);

CREATE OR REPLACE FUNCTION public.is_property_available(
	p_property_id bigint,
	p_check_in_date date,
	p_check_out_date date)
    RETURNS boolean
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
  v_conflict_exists boolean := false;
  v_nights_quantity NUMERIC := 0;
  v_property_exists BIGINT := null;
BEGIN
  v_nights_quantity := p_check_out_date - p_check_in_date;

  if v_nights_quantity <= 0 then
     raise exception 'dates are incorrect.';
  end if;

  SELECT p.property_id         
    INTO v_property_exists
    FROM properties as p 
   WHERE p.property_id = p_property_id;

  if v_property_exists is null then
    RAISE EXCEPTION 'Property % not found.', p_property_id;
  end if;

  SELECT EXISTS (  
     SELECT 1
       FROM reservations AS r
      WHERE r.check_in_date < p_check_out_date
        AND r.check_out_date > p_check_in_date   
        AND r.property_id = p_property_id
		AND r.status IN ('PENDING', 'CONFIRMED')
	) INTO v_conflict_exists;

  return not v_conflict_exists;	

END;
$BODY$;

ALTER FUNCTION public.is_property_available(bigint, date, date)
    OWNER TO postgres;

