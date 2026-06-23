--drop function if exists show_guest_reservations_return_query;


CREATE OR REPLACE FUNCTION show_guest_reservations_return_query( p_guest_id BIGINT)
RETURNS TABLE (
    reservation_id BIGINT,
    property_name VARCHAR(150),
    check_in DATE,
    check_out DATE,
    status VARCHAR(20)
) AS $$
DECLARE
    v_guest_exists BIGINT;

BEGIN
  SELECT g.guest_id         
    INTO v_guest_exists
    FROM guests as g 
   WHERE g.guest_id = p_guest_id;

   if v_guest_exists is null then
     RAISE EXCEPTION 'Guest % not found.', p_guest_id;
   end if;   

   RETURN QUERY
     SELECT r.reservation_id, p.property_name, r.check_in_date, r.check_out_date,
	        r.status
     FROM reservations r
    INNER JOIN properties p
 	   ON p.property_id = r.property_id	
    WHERE r.guest_id = p_guest_id;
 
END;
$$ LANGUAGE plpgsql;

--select * from show_guest_reservations_return_query(1);

--drop function if exists get_table_columns;

--  select * from get_table_columns('properties')