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