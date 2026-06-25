-- FUNCTION: public.calculate_weekly_discount(numeric, integer)

-- DROP FUNCTION IF EXISTS public.calculate_weekly_discount(numeric, integer);

CREATE OR REPLACE FUNCTION public.calculate_weekly_discount(
	p_total_amount numeric,
	p_nights integer)
    RETURNS numeric
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_discount_percent NUMERIC;
    v_min_nights INTEGER;
BEGIN

    IF COALESCE(p_total_amount, 0) <= 0 THEN
        RAISE EXCEPTION 'Amount incorrect.';
    END IF;

    IF COALESCE(p_nights, 0) <= 0 THEN
        RAISE EXCEPTION 'Nights quantity incorrect.';
    END IF;

    v_discount_percent := get_setting('weekly_discount_percent')::NUMERIC;

    v_min_nights := get_setting('weekly_discount_nights')::INTEGER;

    IF p_nights >= v_min_nights THEN
        RETURN p_total_amount * (1 - (v_discount_percent / 100));
    END IF;

    RETURN p_total_amount;

END;
$BODY$;

ALTER FUNCTION public.calculate_weekly_discount(numeric, integer)
    OWNER TO postgres;
