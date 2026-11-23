-- The nine-argument form owns reservation initialization. Every compatibility
-- overload delegates here, using one guest when occupancy is omitted.
CREATE OR REPLACE FUNCTION initialize_reservation(
    p_guest_id           BIGINT,
    p_property_id        BIGINT,
    p_check_in           DATE,
    p_check_out          DATE,
    p_guests_count       INTEGER,
    p_created_by_user_id BIGINT,
    p_services           JSONB,
    p_currency_code      VARCHAR(3),
    p_exchange_rate      NUMERIC
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_amount   NUMERIC(16,6);
    v_reservation_id BIGINT;
    v_is_available   BOOLEAN;
    v_currency_code  VARCHAR(3);
BEGIN
    v_currency_code := validate_currency_exchange_rate(
        p_currency_code,
        p_exchange_rate
    );

    PERFORM validate_booking_dates(p_check_in, p_check_out);

    v_is_available := is_property_available(
        p_property_id,
        p_check_in,
        p_check_out,
        p_guests_count
    );

    IF NOT v_is_available THEN
        RAISE EXCEPTION 'Property is not available for the selected dates or guest count.';
    END IF;

    PERFORM can_guest_book(p_guest_id);

    v_total_amount := calculate_booking_total(
        p_property_id,
        p_check_in,
        p_check_out
    )::NUMERIC(16,6);

    INSERT INTO reservations (
        guest_id,
        property_id,
        guests_count,
        check_in_date,
        check_out_date,
        total_amount,
        status,
        created_by_user_id,
        currency_code,
        exchange_rate
    )
    VALUES (
        p_guest_id,
        p_property_id,
        p_guests_count,
        p_check_in,
        p_check_out,
        v_total_amount,
        'PENDING',
        p_created_by_user_id,
        v_currency_code,
        p_exchange_rate::NUMERIC(20,10)
    )
    RETURNING reservation_id INTO v_reservation_id;

    IF p_services IS NOT NULL THEN
        PERFORM replace_reservation_services(v_reservation_id, p_services);
    END IF;

    RETURN v_reservation_id;
END;
$$;

CREATE OR REPLACE FUNCTION initialize_reservation(
    p_guest_id BIGINT, p_property_id BIGINT, p_check_in DATE, p_check_out DATE,
    p_guests_count INTEGER, p_created_by_user_id BIGINT,
    p_currency_code VARCHAR(3), p_exchange_rate NUMERIC
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN initialize_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out,
        p_guests_count, p_created_by_user_id, NULL::JSONB,
        p_currency_code, p_exchange_rate
    );
END;
$$;

CREATE OR REPLACE FUNCTION initialize_reservation(
    p_guest_id BIGINT, p_property_id BIGINT, p_check_in DATE, p_check_out DATE,
    p_guests_count INTEGER, p_created_by_user_id BIGINT, p_services JSONB
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN initialize_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out,
        p_guests_count, p_created_by_user_id, p_services,
        get_setting('base_currency_code')::VARCHAR(3), 1::NUMERIC
    );
END;
$$;

CREATE OR REPLACE FUNCTION initialize_reservation(
    p_guest_id BIGINT, p_property_id BIGINT, p_check_in DATE, p_check_out DATE,
    p_guests_count INTEGER, p_created_by_user_id BIGINT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN initialize_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out,
        p_guests_count, p_created_by_user_id, NULL::JSONB
    );
END;
$$;

-- Legacy currency/service forms.
CREATE OR REPLACE FUNCTION initialize_reservation(
    p_guest_id BIGINT, p_property_id BIGINT, p_check_in DATE, p_check_out DATE,
    p_created_by_user_id BIGINT, p_services JSONB,
    p_currency_code VARCHAR(3), p_exchange_rate NUMERIC
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN initialize_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out,
        1, p_created_by_user_id, p_services, p_currency_code, p_exchange_rate
    );
END;
$$;

CREATE OR REPLACE FUNCTION initialize_reservation(
    p_guest_id BIGINT, p_property_id BIGINT, p_check_in DATE, p_check_out DATE,
    p_created_by_user_id BIGINT,
    p_currency_code VARCHAR(3), p_exchange_rate NUMERIC
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN initialize_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out,
        1, p_created_by_user_id, NULL::JSONB, p_currency_code, p_exchange_rate
    );
END;
$$;

CREATE OR REPLACE FUNCTION initialize_reservation(
    p_guest_id BIGINT, p_property_id BIGINT, p_check_in DATE, p_check_out DATE,
    p_created_by_user_id BIGINT, p_services JSONB
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN initialize_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out,
        1, p_created_by_user_id, p_services
    );
END;
$$;

CREATE OR REPLACE FUNCTION initialize_reservation(
    p_guest_id BIGINT, p_property_id BIGINT, p_check_in DATE, p_check_out DATE,
    p_created_by_user_id BIGINT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN initialize_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out,
        1, p_created_by_user_id
    );
END;
$$;
