------------------------------------------------------------
-- Source: 01_get_property_rate.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION calculate_stay_cost( p_property_id BIGINT ,
                                                p_check_in_date DATE,
                                                p_check_out_date DATE)
RETURNS NUMERIC AS $$
DECLARE
    v_total_cost NUMERIC      := 0;
	v_nights_quantity NUMERIC := 0;
BEGIN
   --exception error de fechas
   v_nights_quantity = p_check_out_date - p_check_in_date;

   if v_nights_quantity <= 0 then
     raise exception 'dates are incorrect.';
   end if;
   
  -- RETURN v_nights_quantity;

   SELECT p.nightly_rate         
    INTO v_total_cost
    FROM properties as p 
    WHERE p.property_id = p_property_id;

   if v_total_cost is null then
     RAISE EXCEPTION 'Property % not found.', p_property_id;
   end if;
    -- Devuelve el resultado
    RETURN v_nights_quantity * v_total_cost ;
END;
$$ LANGUAGE plpgsql;

------------------------------------------------------------
-- Source: 02_is_property_available.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION is_property_available(p_property_id BIGINT,
                                                 p_check_in_date DATE,
                                                 p_check_out_date DATE)												
RETURNS BOOLEAN AS $$
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
	) INTO v_conflict_exists;

  return not v_conflict_exists;	

END;
$$ LANGUAGE plpgsql;


------------------------------------------------------------
-- Source: 03_show_guest_reservations.sql
------------------------------------------------------------

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




------------------------------------------------------------
-- Source: 04_show_guest_reservations_return_query.sql
------------------------------------------------------------

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



