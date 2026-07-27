CREATE OR REPLACE FUNCTION validate_booking_dates(
    p_check_in_date  DATE,
    p_check_out_date DATE
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_max_stay INTEGER;
BEGIN
    IF p_check_in_date IS NULL THEN
        RAISE EXCEPTION 'Check in date can´t be NULL.';
    END IF;

    IF p_check_out_date IS NULL THEN
        RAISE EXCEPTION 'Check out date can´t be NULL.';
    END IF;

    IF p_check_out_date < p_check_in_date THEN
        RAISE EXCEPTION 'Check in date can´t be after check out date.';
    END IF;

    IF (p_check_out_date - p_check_in_date) < 1 THEN
        RAISE EXCEPTION 'The stay can´t be less than a night.';
    END IF;

    v_max_stay := get_setting('max_stay_nights')::INTEGER;

    IF v_max_stay < (p_check_out_date - p_check_in_date) THEN
        RAISE EXCEPTION 'The maximum stay is 30 nights.';
    END IF;

    RETURN TRUE;
END;
$$;