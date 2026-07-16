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

SELECT * FROM calculate_stay_cost(1,'2026-01-01', '2026-01-31');