------------------------------------------------------------
-- PostgreSQL Development Lab
-- Scenario: 02_functions_business_rules
--
-- AUTO-GENERATED FILE
-- DO NOT EDIT MANUALLY
------------------------------------------------------------

------------------------------------------------------------
-- Source: 01_calculate_booking_discount.sql
------------------------------------------------------------

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
        RETURN p_total_amount;
    END IF;

    RETURN p_total_amount * (1 - v_discount_percent / 100);
END;
$$;


------------------------------------------------------------
-- Source: 02_validate_booking_dates.sql
------------------------------------------------------------

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
        RAISE EXCEPTION 'Check in date canÂ´t be NULL.';
    END IF;

    IF p_check_out_date IS NULL THEN
        RAISE EXCEPTION 'Check out date canÂ´t be NULL.';
    END IF;

    IF p_check_out_date < p_check_in_date THEN
        RAISE EXCEPTION 'Check in date canÂ´t be after check out date.';
    END IF;

    IF (p_check_out_date - p_check_in_date) < 1 THEN
        RAISE EXCEPTION 'The stay canÂ´t be less than a night.';
    END IF;

    v_max_stay := get_setting('max_stay_nights')::INTEGER;

    IF v_max_stay < (p_check_out_date - p_check_in_date) THEN
        RAISE EXCEPTION 'The maximum stay is 30 nights.';
    END IF;

    RETURN TRUE;
END;
$$;


------------------------------------------------------------
-- Source: 03_can_guest_book.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION can_guest_book(
    p_guest_id BIGINT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_guest_exists       BIGINT;
    v_reservation_count  INT;
    v_max_pending        INTEGER;
BEGIN
    SELECT g.guest_id
    INTO v_guest_exists
    FROM guests AS g
    WHERE g.guest_id = p_guest_id;

    IF v_guest_exists IS NULL THEN
        RAISE EXCEPTION 'Guest not found.';
    END IF;

    SELECT COUNT(*)
    INTO v_reservation_count
    FROM reservations AS r
    WHERE r.guest_id = p_guest_id
      AND r.status = 'PENDING';

    v_max_pending := get_setting('max_pending_reservations')::INTEGER;

    IF v_max_pending <= v_reservation_count THEN
        RAISE EXCEPTION 'Guest has reached the maximum number of pending reservations.';
    END IF;

    RETURN TRUE;
END;
$$;


------------------------------------------------------------
-- Source: 04_calculate_booking_total.sql
------------------------------------------------------------

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


------------------------------------------------------------
-- Source: 05_create_reservation.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id    BIGINT,
    p_property_id BIGINT,
    p_check_in    DATE,
    p_check_out   DATE
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_amount   NUMERIC;
    v_reservation_id BIGINT;
    v_is_available   BOOLEAN;
BEGIN
    PERFORM validate_booking_dates(
        p_check_in,
        p_check_out
    );

    v_is_available := is_property_available(
        p_property_id,
        p_check_in,
        p_check_out
    );

    IF NOT v_is_available THEN
        RAISE EXCEPTION 'Property is not available for the selected dates.';
    END IF;

    PERFORM can_guest_book(
        p_guest_id
    );

    v_total_amount := calculate_booking_total(
        p_property_id,
        p_check_in,
        p_check_out
    );

    INSERT INTO reservations (
        guest_id,
        property_id,
        check_in_date,
        check_out_date,
        total_amount,
        status
    )
    VALUES (
        p_guest_id,
        p_property_id,
        p_check_in,
        p_check_out,
        v_total_amount,
        'PENDING'
    )
    RETURNING reservation_id
    INTO v_reservation_id;

    RETURN v_reservation_id;
END;
$$;


------------------------------------------------------------
-- Source: 06_process_booking.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION process_booking(
    p_guest_id       BIGINT,
    p_property_id    BIGINT,
    p_check_in       DATE,
    p_check_out      DATE,
    p_payment_amount NUMERIC(12,2),
    p_payment_method VARCHAR(30)
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_reservation_id BIGINT;
    v_total_amount   NUMERIC;
BEGIN
    IF COALESCE(p_payment_amount, 0) <= 0 THEN
        RAISE EXCEPTION
            'Payment amount must be greater than zero.';
    END IF;

    IF p_payment_method IS NULL THEN
        RAISE EXCEPTION
            'Payment method cannot be NULL.';
    END IF;

    v_reservation_id := create_reservation(
        p_guest_id,
        p_property_id,
        p_check_in,
        p_check_out
    );

    SELECT total_amount
    INTO v_total_amount
    FROM reservations
    WHERE reservation_id = v_reservation_id;

    IF ABS(v_total_amount - p_payment_amount) >= 0.01 THEN
        RAISE EXCEPTION
            'Payment amount does not match the reservation total.';
    END IF;

    INSERT INTO payments (
        reservation_id,
        payment_amount,
        payment_method,
        status,
        payment_date
    )
    VALUES (
        v_reservation_id,
        p_payment_amount,
        p_payment_method,
        'PAID',
        CURRENT_DATE
    );

    PERFORM confirm_reservation(v_reservation_id);

    RETURN v_reservation_id;
END;
$$;


------------------------------------------------------------
-- Source: 07_confirm_reservation.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION confirm_reservation(
    p_reservation_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
BEGIN
    SELECT status
    INTO v_status
    FROM reservations AS r
    WHERE reservation_id = p_reservation_id;

    IF v_status IS NULL THEN
        RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    IF v_status <> 'PENDING' THEN
        RAISE EXCEPTION 'Reservation must be PENDING.';
    END IF;

    UPDATE reservations
    SET status = 'CONFIRMED'
    WHERE reservation_id = p_reservation_id;
END;
$$;


------------------------------------------------------------
-- Source: 08_cancel_reservation.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION cancel_reservation(
    p_reservation_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
BEGIN
    SELECT status
    INTO v_status
    FROM reservations
    WHERE reservation_id = p_reservation_id;

    IF v_status IS NULL THEN
        RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE EXCEPTION 'Reservation is already cancelled.';
    END IF;

    UPDATE reservations
    SET status = 'CANCELLED'
    WHERE reservation_id = p_reservation_id;
END;
$$;



