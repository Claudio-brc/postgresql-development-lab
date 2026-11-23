-- The twelve-argument form owns public creation. It keeps the existing
-- reservation/payment snapshots independent and adds only occupancy.
CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id BIGINT, p_property_id BIGINT, p_check_in DATE, p_check_out DATE,
    p_guests_count INTEGER,
    p_payment_amount NUMERIC, p_payment_method VARCHAR(30),
    p_created_by_user_id BIGINT, p_services JSONB,
    p_currency_code VARCHAR(3),
    p_reservation_exchange_rate NUMERIC,
    p_payment_exchange_rate NUMERIC
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_reservation_id BIGINT;
BEGIN
    v_reservation_id := initialize_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out,
        p_guests_count, p_created_by_user_id, p_services,
        p_currency_code, p_reservation_exchange_rate
    );

    IF p_payment_amount IS NULL
       AND p_payment_method IS NULL
       AND p_payment_exchange_rate IS NULL THEN
        RETURN v_reservation_id;
    END IF;

    IF p_payment_amount IS NULL
       OR p_payment_method IS NULL
       OR p_payment_exchange_rate IS NULL THEN
        RAISE EXCEPTION 'Payment amount, payment method, and payment exchange rate must be supplied together.';
    END IF;

    PERFORM process_reservation_payment(
        v_reservation_id,
        p_payment_amount,
        p_payment_method,
        p_payment_exchange_rate
    );

    RETURN v_reservation_id;
END;
$$;

-- Guest-aware explicit-currency paid creation without services.
CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id BIGINT, p_property_id BIGINT, p_check_in DATE, p_check_out DATE,
    p_guests_count INTEGER,
    p_payment_amount NUMERIC, p_payment_method VARCHAR(30),
    p_created_by_user_id BIGINT, p_currency_code VARCHAR(3),
    p_reservation_exchange_rate NUMERIC, p_payment_exchange_rate NUMERIC
)
RETURNS BIGINT LANGUAGE plpgsql AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out, p_guests_count,
        p_payment_amount, p_payment_method, p_created_by_user_id, NULL::JSONB,
        p_currency_code, p_reservation_exchange_rate, p_payment_exchange_rate
    );
END;
$$;

-- Guest-aware explicit-currency unpaid creation.
CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id BIGINT, p_property_id BIGINT, p_check_in DATE, p_check_out DATE,
    p_guests_count INTEGER, p_created_by_user_id BIGINT, p_services JSONB,
    p_currency_code VARCHAR(3), p_reservation_exchange_rate NUMERIC
)
RETURNS BIGINT LANGUAGE plpgsql AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out, p_guests_count,
        NULL::NUMERIC, NULL::VARCHAR(30), p_created_by_user_id, p_services,
        p_currency_code, p_reservation_exchange_rate, NULL::NUMERIC
    );
END;
$$;

-- Guest-aware base-currency convenience forms.
CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id BIGINT, p_property_id BIGINT, p_check_in DATE, p_check_out DATE,
    p_guests_count INTEGER,
    p_payment_amount NUMERIC, p_payment_method VARCHAR(30),
    p_created_by_user_id BIGINT, p_services JSONB
)
RETURNS BIGINT LANGUAGE plpgsql AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out, p_guests_count,
        p_payment_amount, p_payment_method, p_created_by_user_id, p_services,
        get_setting('base_currency_code')::VARCHAR(3), 1::NUMERIC,
        CASE WHEN p_payment_amount IS NULL AND p_payment_method IS NULL
             THEN NULL::NUMERIC ELSE 1::NUMERIC END
    );
END;
$$;

CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id BIGINT, p_property_id BIGINT, p_check_in DATE, p_check_out DATE,
    p_guests_count INTEGER,
    p_payment_amount NUMERIC, p_payment_method VARCHAR(30),
    p_created_by_user_id BIGINT
)
RETURNS BIGINT LANGUAGE plpgsql AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out, p_guests_count,
        p_payment_amount, p_payment_method, p_created_by_user_id, NULL::JSONB
    );
END;
$$;

CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id BIGINT, p_property_id BIGINT, p_check_in DATE, p_check_out DATE,
    p_guests_count INTEGER, p_created_by_user_id BIGINT, p_services JSONB
)
RETURNS BIGINT LANGUAGE plpgsql AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out, p_guests_count,
        p_created_by_user_id, p_services,
        get_setting('base_currency_code')::VARCHAR(3), 1::NUMERIC
    );
END;
$$;

CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id BIGINT, p_property_id BIGINT, p_check_in DATE, p_check_out DATE,
    p_guests_count INTEGER, p_created_by_user_id BIGINT
)
RETURNS BIGINT LANGUAGE plpgsql AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out,
        p_guests_count, p_created_by_user_id, NULL::JSONB
    );
END;
$$;

-- All pre-capacity call shapes remain available and delegate with one guest.
CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id BIGINT, p_property_id BIGINT, p_check_in DATE, p_check_out DATE,
    p_payment_amount NUMERIC, p_payment_method VARCHAR(30),
    p_created_by_user_id BIGINT, p_services JSONB,
    p_currency_code VARCHAR(3), p_reservation_exchange_rate NUMERIC,
    p_payment_exchange_rate NUMERIC
)
RETURNS BIGINT LANGUAGE plpgsql AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out, 1,
        p_payment_amount, p_payment_method, p_created_by_user_id, p_services,
        p_currency_code, p_reservation_exchange_rate, p_payment_exchange_rate
    );
END;
$$;

CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id BIGINT, p_property_id BIGINT, p_check_in DATE, p_check_out DATE,
    p_payment_amount NUMERIC, p_payment_method VARCHAR(30),
    p_created_by_user_id BIGINT, p_currency_code VARCHAR(3),
    p_reservation_exchange_rate NUMERIC, p_payment_exchange_rate NUMERIC
)
RETURNS BIGINT LANGUAGE plpgsql AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out, 1,
        p_payment_amount, p_payment_method, p_created_by_user_id, NULL::JSONB,
        p_currency_code, p_reservation_exchange_rate, p_payment_exchange_rate
    );
END;
$$;

CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id BIGINT, p_property_id BIGINT, p_check_in DATE, p_check_out DATE,
    p_created_by_user_id BIGINT, p_services JSONB,
    p_currency_code VARCHAR(3), p_reservation_exchange_rate NUMERIC
)
RETURNS BIGINT LANGUAGE plpgsql AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out, 1,
        p_created_by_user_id, p_services,
        p_currency_code, p_reservation_exchange_rate
    );
END;
$$;

CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id BIGINT, p_property_id BIGINT, p_check_in DATE, p_check_out DATE,
    p_payment_amount NUMERIC, p_payment_method VARCHAR(30),
    p_created_by_user_id BIGINT, p_services JSONB
)
RETURNS BIGINT LANGUAGE plpgsql AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out, 1,
        p_payment_amount, p_payment_method, p_created_by_user_id, p_services
    );
END;
$$;

CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id BIGINT, p_property_id BIGINT, p_check_in DATE, p_check_out DATE,
    p_payment_amount NUMERIC, p_payment_method VARCHAR(30),
    p_created_by_user_id BIGINT
)
RETURNS BIGINT LANGUAGE plpgsql AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out, 1,
        p_payment_amount, p_payment_method, p_created_by_user_id, NULL::JSONB
    );
END;
$$;

CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id BIGINT, p_property_id BIGINT, p_check_in DATE, p_check_out DATE,
    p_created_by_user_id BIGINT, p_services JSONB
)
RETURNS BIGINT LANGUAGE plpgsql AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out,
        1, p_created_by_user_id, p_services
    );
END;
$$;

CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id BIGINT, p_property_id BIGINT, p_check_in DATE, p_check_out DATE,
    p_created_by_user_id BIGINT
)
RETURNS BIGINT LANGUAGE plpgsql AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id, p_property_id, p_check_in, p_check_out,
        1, p_created_by_user_id
    );
END;
$$;
