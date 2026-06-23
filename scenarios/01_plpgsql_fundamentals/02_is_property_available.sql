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