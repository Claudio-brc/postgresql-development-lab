-- DROP FUNCTION IF EXISTS public.add_services_to_reservation(bigint, JSONB);

CREATE OR REPLACE FUNCTION public.add_services_to_reservation(
    p_reservation_id BIGINT,
    p_services JSONB
)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
	v_service_id BIGINT;
	v_service    JSONB;
	v_unit_price NUMERIC;
	v_quantity   INTEGER; 
BEGIN

  IF NOT EXISTS (
    SELECT 1
    FROM reservations
    WHERE reservation_id = p_reservation_id) THEN
    
	RAISE EXCEPTION
        'Reservation % not found.',
        p_reservation_id;
  END IF;

  IF p_services IS NULL THEN
    RETURN;
  END IF;

  IF jsonb_typeof(p_services) <> 'array' THEN
    RAISE EXCEPTION
        'Expected a JSON array.';
  END IF;

  IF jsonb_array_length(p_services) = 0 THEN
    RETURN;
  END IF;

  DELETE FROM reservation_services 
    WHERE reservation_id = p_reservation_id;



  FOR v_service IN
    SELECT *
    FROM jsonb_array_elements(p_services)
  LOOP

    v_service_id := (v_service ->> 'service_id')::BIGINT;
    v_quantity   := (v_service ->> 'quantity')::INTEGER;

    SELECT price
	  INTO v_unit_price
      FROM services   
	 WHERE service_id = v_service_id;

    IF v_unit_price IS NULL THEN
	  RAISE EXCEPTION 'Service % not found.', v_service_id;
	END IF;  

	INSERT INTO public.reservation_services(
	 reservation_id, service_id, quantity, unit_price)
	VALUES ( p_reservation_id,v_service_id, v_quantity , v_unit_price);

    
  END LOOP;  

END;
$BODY$;

ALTER FUNCTION public.add_services_to_reservation(bigint, JSONB)
    OWNER TO postgres;

