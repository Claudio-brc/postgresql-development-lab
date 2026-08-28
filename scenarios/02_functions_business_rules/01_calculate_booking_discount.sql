CREATE OR REPLACE FUNCTION calculate_booking_discount(
    p_total_amount NUMERIC,
    p_nights       INTEGER,
    p_check_in     DATE
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_discount_percent NUMERIC;
BEGIN
    IF p_check_in IS NULL THEN
        RAISE EXCEPTION 'Check-in date cannot be NULL.';
    END IF;

    IF COALESCE(p_total_amount, 0) <= 0 THEN
        RAISE EXCEPTION 'Amount incorrect.';
    END IF;

    IF COALESCE(p_nights, 0) <= 0 THEN
        RAISE EXCEPTION 'Nights quantity incorrect.';
    END IF;

    SELECT discount_percent
    INTO v_discount_percent
    FROM discounts
    WHERE is_active = TRUE
      AND (
            (
                discount_type = 'STAY_LENGTH'
                AND minimum_nights <= p_nights
            )
            OR
            (
                discount_type = 'DATE_RANGE'
                AND p_check_in BETWEEN valid_from AND valid_to
            )
          )
    ORDER BY discount_percent DESC
    LIMIT 1;

    IF v_discount_percent IS NULL THEN
        RETURN p_total_amount::NUMERIC(16,6);
    END IF;

    RETURN (
        p_total_amount * (1 - v_discount_percent / 100)
    )::NUMERIC(16,6);
END;
$$;
