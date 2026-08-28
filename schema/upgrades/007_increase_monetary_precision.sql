-- Apply after 006_add_application_users.sql.
--
-- Increasing scale from 2 to 6 preserves every existing monetary value. The
-- precision is widened by four digits as well, so the maximum whole-number
-- range of each column remains unchanged.

BEGIN;

ALTER TABLE public.properties
    ALTER COLUMN nightly_rate TYPE NUMERIC(16,6);

ALTER TABLE public.reservations
    ALTER COLUMN total_amount TYPE NUMERIC(16,6);

ALTER TABLE public.payments
    ALTER COLUMN payment_amount TYPE NUMERIC(16,6);

ALTER TABLE public.services
    ALTER COLUMN price TYPE NUMERIC(14,6);

ALTER TABLE public.reservation_services
    ALTER COLUMN unit_price TYPE NUMERIC(14,6);

ALTER TYPE public.property_request
    ALTER ATTRIBUTE nightly_rate TYPE NUMERIC(16,6) CASCADE;

ALTER TYPE public.reservation_summary
    ALTER ATTRIBUTE total_amount TYPE NUMERIC(16,6) CASCADE;

ALTER TYPE public.service_summary
    ALTER ATTRIBUTE unit_price TYPE NUMERIC(14,6) CASCADE;

-- PostgreSQL discards NUMERIC typemods in function signatures, so the
-- calculation boundary is enforced with explicit casts in the function body.
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
    )::NUMERIC(16,6);
END;
$$;

COMMIT;
