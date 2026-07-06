-- FUNCTION: public.get_reservation_summary(bigint)

-- DROP FUNCTION IF EXISTS public.get_reservation_summary(bigint);

CREATE OR REPLACE FUNCTION public.get_reservation_summary(
	p_reservation_id bigint)
    RETURNS reservation_summary
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
  v_reservation reservation_summary  ;
BEGIN

    SELECT 
        (r.reservation_id, g.name, p.name, r.total_amount, r.status)::reservation_summary
    INTO 
        v_reservation
    FROM 
        reservations r
    JOIN 
        guests g ON r.guest_id = g.guest_id
    JOIN 
        properties p ON r.property_id = p.property_id
    WHERE 
        r.reservation_id = p_reservation_id;

	RETURN v_reservation;	

END;
$BODY$;

ALTER FUNCTION public.get_reservation_summary(bigint)
    OWNER TO postgres;
