------------------------------------------------------------
-- PostgreSQL Development Lab
-- Scenario: 09_property_capacity
--
-- AUTO-GENERATED FILE
-- DO NOT EDIT MANUALLY
------------------------------------------------------------

------------------------------------------------------------
-- Source: 01_is_property_available.sql
------------------------------------------------------------

-- The four-argument form is the canonical implementation. The historical
-- three-argument form delegates with the compatibility occupancy of one.
CREATE OR REPLACE FUNCTION is_property_available(
    p_property_id    BIGINT,
    p_check_in_date  DATE,
    p_check_out_date DATE,
    p_guests_count   INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_conflict_exists   BOOLEAN := FALSE;
    v_nights_quantity  INTEGER;
    v_property_is_active BOOLEAN;
    v_max_guests       INTEGER;
BEGIN
    IF p_guests_count IS NULL OR p_guests_count <= 0 THEN
        RAISE EXCEPTION 'Guest count must be greater than zero.';
    END IF;

    v_nights_quantity := p_check_out_date - p_check_in_date;

    IF v_nights_quantity <= 0 THEN
        RAISE EXCEPTION 'dates are incorrect.';
    END IF;

    SELECT p.is_active, p.max_guests
    INTO v_property_is_active, v_max_guests
    FROM properties AS p
    WHERE p.property_id = p_property_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Property % not found.', p_property_id;
    END IF;

    IF NOT v_property_is_active OR p_guests_count > v_max_guests THEN
        RETURN FALSE;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM reservations AS r
        WHERE r.check_in_date < p_check_out_date
          AND r.check_out_date > p_check_in_date
          AND r.property_id = p_property_id
          AND r.status IN ('PENDING', 'CONFIRMED')
    )
    INTO v_conflict_exists;

    RETURN NOT v_conflict_exists;
END;
$$;

CREATE OR REPLACE FUNCTION is_property_available(
    p_property_id    BIGINT,
    p_check_in_date  DATE,
    p_check_out_date DATE
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN is_property_available(
        p_property_id,
        p_check_in_date,
        p_check_out_date,
        1
    );
END;
$$;



------------------------------------------------------------
-- Source: 02_enforce_reservation_capacity.sql
------------------------------------------------------------

-- Table checks reject non-positive values. This trigger also protects direct
-- reservation writes from exceeding the property's current capacity.
CREATE OR REPLACE FUNCTION enforce_reservation_capacity()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_max_guests INTEGER;
BEGIN
    SELECT p.max_guests
    INTO v_max_guests
    FROM properties AS p
    WHERE p.property_id = NEW.property_id
    FOR SHARE;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    IF NEW.guests_count > v_max_guests THEN
        RAISE EXCEPTION
            'Guest count % exceeds maximum capacity % for property %.',
            NEW.guests_count,
            v_max_guests,
            NEW.property_id;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_reservations_enforce_capacity ON reservations;

CREATE TRIGGER trg_reservations_enforce_capacity
BEFORE INSERT OR UPDATE OF property_id, guests_count ON reservations
FOR EACH ROW
EXECUTE FUNCTION enforce_reservation_capacity();



------------------------------------------------------------
-- Source: 03_create_property.sql
------------------------------------------------------------

-- The two-argument form accepts capacity explicitly. The original composite
-- overload remains operational and creates a one-guest property.
CREATE OR REPLACE FUNCTION create_property(
    p_property property_request,
    p_max_guests INTEGER
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_property_id BIGINT;
BEGIN
    IF p_max_guests IS NULL OR p_max_guests <= 0 THEN
        RAISE EXCEPTION 'Maximum guest capacity must be greater than zero.';
    END IF;

    INSERT INTO properties (
        property_name,
        nightly_rate,
        max_guests,
        is_active,
        property_type,
        property_code,
        metadata
    )
    VALUES (
        p_property.property_name,
        p_property.nightly_rate,
        p_max_guests,
        COALESCE(p_property.is_active, TRUE),
        p_property.property_type,
        p_property.property_code,
        p_property.metadata
    )
    RETURNING property_id
    INTO v_property_id;

    RETURN v_property_id;
END;
$$;

CREATE OR REPLACE FUNCTION create_property(
    p_property property_request
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN create_property(p_property, 1);
END;
$$;



------------------------------------------------------------
-- Source: 04_initialize_reservation.sql
------------------------------------------------------------

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



------------------------------------------------------------
-- Source: 05_create_reservation.sql
------------------------------------------------------------

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




