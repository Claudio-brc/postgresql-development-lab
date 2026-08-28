CREATE OR REPLACE FUNCTION calculate_stay_cost(
    p_property_id    BIGINT,
    p_check_in_date  DATE,
    p_check_out_date DATE
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_cost       NUMERIC := 0;
    v_nights_quantity  NUMERIC := 0;
BEGIN
    --exception error de fechas
    v_nights_quantity := p_check_out_date - p_check_in_date;

    IF v_nights_quantity <= 0 THEN
        RAISE EXCEPTION 'dates are incorrect.';
    END IF;

    SELECT p.nightly_rate
    INTO v_total_cost
    FROM properties AS p
    WHERE p.property_id = p_property_id;

    IF v_total_cost IS NULL THEN
        RAISE EXCEPTION 'Property % not found.', p_property_id;
    END IF;

    RETURN (v_nights_quantity * v_total_cost)::NUMERIC(16,6);
END;
$$;
