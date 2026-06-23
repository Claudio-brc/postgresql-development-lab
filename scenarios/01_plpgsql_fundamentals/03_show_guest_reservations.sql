--drop function if exists show_guest_reservations;


CREATE OR REPLACE FUNCTION show_guest_reservations( p_guest_id BIGINT)
RETURNS TABLE (
    reservation_id BIGINT,
    property_name VARCHAR(150),
    check_in DATE,
    check_out DATE,
    status TEXT
) AS $$
DECLARE
    v_guest_exists BIGINT;
    rec RECORD;
BEGIN
  SELECT g.guest_id         
    INTO v_guest_exists
    FROM guests as g 
   WHERE g.guest_id = p_guest_id;

   if v_guest_exists is null then
     RAISE EXCEPTION 'Guest % not found.', p_guest_id;
   end if;   

   FOR rec IN
     SELECT r.reservation_id, p.property_name, r.check_in_date, r.check_out_date,
	        r.status
     FROM reservations r
    INNER JOIN properties p
 	   ON p.property_id = r.property_id	
    WHERE r.guest_id = p_guest_id
    LOOP
      reservation_id := rec.reservation_id;
	  property_name  := rec.property_name;
	  check_in       := rec.check_in_date;
	  check_out      := rec.check_out_date;
	  status         := rec.status;

      RETURN NEXT;
    END LOOP; 
END;
$$ LANGUAGE plpgsql;

--select * from show_guest_reservations(1);

