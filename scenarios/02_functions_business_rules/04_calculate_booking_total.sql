CREATE OR REPLACE FUNCTION calculate_booking_total(
    p_property_id BIGINT,
    p_check_in    DATE,
    p_check_out   DATE
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_base NUMERIC;
BEGIN
    PERFORM validate_booking_dates(p_check_in, p_check_out);

    v_total_base := calculate_stay_cost(
        p_property_id,
        p_check_in,
        p_check_out
    );

    RETURN calculate_booking_discount(
        v_total_base,
        p_check_out - p_check_in,
        p_check_in
    );
END;
$$;