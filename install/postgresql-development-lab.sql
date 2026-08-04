------------------------------------------------------------
-- PostgreSQL Development Lab
--
-- Master installation script
--
-- AUTO-GENERATED FILE
-- DO NOT EDIT MANUALLY
------------------------------------------------------------

------------------------------------------------------------
-- Schema: 00_custom_types
------------------------------------------------------------

DROP TYPE IF EXISTS property_request CASCADE;

DROP TYPE IF EXISTS reservation_summary CASCADE;

DROP TYPE IF EXISTS service_summary CASCADE;


CREATE TYPE property_request AS (
    property_name VARCHAR(150),
    nightly_rate NUMERIC,
    is_active BOOLEAN
);

CREATE TYPE reservation_summary AS
(
    reservation_id BIGINT,
    guest_name VARCHAR(150),
    property_name VARCHAR(150),
    total_amount NUMERIC,
    status VARCHAR(20)
);

CREATE TYPE service_summary AS
(
    service_id BIGINT,
    service_name VARCHAR(100),
    quantity INTEGER,
    unit_price NUMERIC(10,2)
);

------------------------------------------------------------
-- Schema: 01_core_schema
------------------------------------------------------------

DROP TABLE IF EXISTS reservation_services CASCADE;
DROP TABLE IF EXISTS services CASCADE;
DROP TABLE IF EXISTS error_log CASCADE;
DROP TABLE IF EXISTS reservation_status_audit CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS reservations CASCADE;
DROP TABLE IF EXISTS properties CASCADE;
DROP TABLE IF EXISTS guests CASCADE;
DROP TABLE IF EXISTS discounts CASCADE;
DROP TABLE IF EXISTS app_settings CASCADE;

CREATE EXTENSION IF NOT EXISTS btree_gist;


CREATE TABLE guests (
    guest_id      BIGSERIAL PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    email         VARCHAR(255) NOT NULL UNIQUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMPTZ  

);

CREATE TABLE properties (
    property_id     BIGSERIAL PRIMARY KEY,
    property_name   VARCHAR(150) NOT NULL,

    nightly_rate    NUMERIC(12,2)
                     NOT NULL
                     CHECK (nightly_rate >= 0),

    is_active       BOOLEAN NOT NULL DEFAULT TRUE,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at      TIMESTAMPTZ,

    metadata        JSONB  
);

CREATE TABLE reservations (
    reservation_id      BIGSERIAL PRIMARY KEY,

    guest_id            BIGINT NOT NULL,

    property_id         BIGINT NOT NULL,

    check_in_date       DATE NOT NULL,

    check_out_date      DATE NOT NULL,

    status              VARCHAR(20)
                        NOT NULL
                        DEFAULT 'PENDING'
                        CHECK (
                            status IN (
                                'PENDING',
                                'CONFIRMED',
                                'CANCELLED'
                            )
                        ),

    total_amount        NUMERIC(12,2)
                        NOT NULL
                        DEFAULT 0
                        CHECK (total_amount >= 0),

    created_at          TIMESTAMPTZ
                        NOT NULL
                        DEFAULT CURRENT_TIMESTAMP,

    updated_at          TIMESTAMPTZ,

    CONSTRAINT fk_reservations_guests
        FOREIGN KEY (guest_id)
        REFERENCES guests(guest_id),

    CONSTRAINT fk_reservations_properties
        FOREIGN KEY (property_id)
        REFERENCES properties(property_id),

    CONSTRAINT chk_reservation_dates
        CHECK (check_out_date > check_in_date)
);

ALTER TABLE reservations
ADD CONSTRAINT exclude_overlapping_active_reservations
EXCLUDE USING gist (
    property_id WITH =,
    daterange(check_in_date, check_out_date, '[)') WITH &&
)
WHERE (status IN ('PENDING', 'CONFIRMED'));

CREATE TABLE payments (
    payment_id          BIGSERIAL PRIMARY KEY,

    reservation_id      BIGINT NOT NULL,

    payment_amount      NUMERIC(12,2)
                        NOT NULL
                        CHECK (payment_amount > 0),

    payment_method      VARCHAR(30) NOT NULL,

    status              VARCHAR(20)
                        NOT NULL
                        DEFAULT 'PENDING'
                        CHECK (
                            status IN (
                                'PENDING',
                                'PAID',
                                'REFUNDED'
                            )
                        ),                    
    payment_date        TIMESTAMPTZ
                        NOT NULL
                        DEFAULT CURRENT_TIMESTAMP,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at          TIMESTAMPTZ,                         

    CONSTRAINT fk_payments_reservations
        FOREIGN KEY (reservation_id)
        REFERENCES reservations(reservation_id)
);

CREATE TABLE app_settings (

    setting_key     VARCHAR(100) PRIMARY KEY,

    setting_value   VARCHAR(255) NOT NULL,

    description     VARCHAR(255)

);

CREATE TABLE discounts (

    discount_id         BIGSERIAL PRIMARY KEY,

    discount_name       VARCHAR(100) NOT NULL,

    discount_type       VARCHAR(20) NOT NULL
                        CHECK (
                            discount_type IN (
                                'STAY_LENGTH',
                                'DATE_RANGE'
                            )
                        ),

    discount_percent    NUMERIC(5,2) NOT NULL
                        CHECK (
                            discount_percent > 0
                            AND discount_percent <= 100
                        ),

    minimum_nights      INTEGER
                        CHECK (minimum_nights > 0),

    valid_from          DATE,

    valid_to            DATE,

    is_active           BOOLEAN NOT NULL DEFAULT TRUE,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at          TIMESTAMPTZ,

    CONSTRAINT chk_discount_dates
    CHECK (
        valid_from IS NULL
        OR valid_to IS NULL
        OR valid_from <= valid_to
    )

);

CREATE TABLE reservation_status_audit (
    audit_id BIGSERIAL PRIMARY KEY,
    reservation_id BIGINT NOT NULL,
    old_status VARCHAR(20),
    new_status VARCHAR(20),
    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_reservation_audit_reservation 
   FOREIGN KEY (reservation_id) REFERENCES reservations(reservation_id)
);


CREATE TABLE error_log (
    error_id BIGSERIAL PRIMARY KEY,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    sql_state VARCHAR(10),
    error_message TEXT,
    function_name VARCHAR(100)
);

CREATE TABLE services
(
    service_id BIGSERIAL PRIMARY KEY,
    service_name VARCHAR(100) NOT NULL,
    description TEXT,
    price NUMERIC(10,2) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ,

    CHECK (price >= 0)
);

CREATE TABLE reservation_services
(
    reservation_id BIGINT NOT NULL,
    service_id BIGINT NOT NULL,

    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price NUMERIC(10,2) NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_reservation_services
        PRIMARY KEY (reservation_id, service_id),

    CONSTRAINT fk_reservation_services_reservation
        FOREIGN KEY (reservation_id)
        REFERENCES reservations(reservation_id),

    CONSTRAINT fk_reservation_services_service
        FOREIGN KEY (service_id)
        REFERENCES services(service_id)
);


CREATE OR REPLACE FUNCTION get_setting(
    p_setting_key VARCHAR
)
RETURNS VARCHAR AS $$
DECLARE
    v_setting_value VARCHAR;
BEGIN

    SELECT setting_value
      INTO v_setting_value
      FROM app_settings
     WHERE setting_key = p_setting_key;

    IF v_setting_value IS NULL THEN
        RAISE EXCEPTION
            'Setting "%" not found.',
            p_setting_key;
    END IF;

    RETURN v_setting_value;

END;
$$ LANGUAGE plpgsql;



------------------------------------------------------------
-- Schema: 02_seed_data
------------------------------------------------------------

INSERT INTO guests (full_name, email)
SELECT
    'Guest ' || n,
    'guest' || n || '@example.com'
FROM generate_series(1,20) AS n;

INSERT INTO properties (property_name, nightly_rate)
VALUES
('Lake View Cabin', 120.00),
('Mountain Retreat', 150.00),
('Downtown Apartment', 90.00),
('Patagonia Loft', 110.00),
('Forest House', 180.00),
('Riverside Cottage', 140.00),
('City Studio', 75.00),
('Lakeside Bungalow', 200.00),
('Family Cabin', 160.00),
('Luxury Suite', 300.00);

INSERT INTO reservations (
    guest_id,
    property_id,
    check_in_date,
    check_out_date,
    status,
    total_amount
)
VALUES
(1,1,'2026-07-01','2026-07-05','CONFIRMED',480.00),
(2,2,'2026-07-10','2026-07-15','CONFIRMED',750.00),
(3,3,'2026-08-01','2026-08-04','PENDING',270.00),
(4,4,'2026-08-10','2026-08-15','CONFIRMED',550.00),
(5,5,'2026-09-01','2026-09-03','CANCELLED',360.00),
(6,1,'2026-09-10','2026-09-15','CONFIRMED',600.00),
(7,6,'2026-10-01','2026-10-04','PENDING',420.00),
(8,7,'2026-10-10','2026-10-12','CONFIRMED',150.00),
(9,8,'2026-11-01','2026-11-05','CONFIRMED',800.00),
(10,9,'2026-11-15','2026-11-18','PENDING',480.00);


INSERT INTO payments (
    reservation_id,
    payment_amount,
    payment_method,
    status
)
VALUES
(1,480.00,'CREDIT_CARD','PAID'),
(2,750.00,'BANK_TRANSFER','PAID'),
(4,550.00,'DEBIT_CARD','PAID'),
(6,600.00,'BANK_TRANSFER','PAID'),
(8,150.00,'CREDIT_CARD','PAID'),
(9,800.00,'BANK_TRANSFER','PAID');

INSERT INTO app_settings
(setting_key, setting_value, description)
VALUES
('weekly_discount_percent', '10', 'Discount applied to weekly stays'),

('weekly_discount_nights', '7', 'Minimum nights to apply weekly discount'),

('max_pending_reservations', '3', 'Maximum pending reservations per guest'),

('max_stay_nights', '30', 'Maximum allowed stay');

INSERT INTO discounts
(
    discount_name,
    discount_type,
    discount_percent,
    minimum_nights
)
VALUES
(
    'Weekly Discount',
    'STAY_LENGTH',
    10,
    7
);

INSERT INTO discounts
(
    discount_name,
    discount_type,
    discount_percent,
    minimum_nights
)
VALUES
(
    'Monthly Discount',
    'STAY_LENGTH',
    20,
    30
);

INSERT INTO discounts
(
    discount_name,
    discount_type,
    discount_percent,
    valid_from,
    valid_to
)
VALUES
(
    'Low Season',
    'DATE_RANGE',
    15,
    '2026-05-01',
    '2026-06-30'
);

INSERT INTO services
(
    service_name,
    description,
    price
)
VALUES
(
    'Breakfast',
    'Continental breakfast served every morning.',
    15.00
),
(
    'Airport Transfer',
    'Private transfer between the airport and the property.',
    40.00
),
(
    'Late Check-out',
    'Extended check-out after the standard departure time.',
    25.00
),
(
    'Pet Fee',
    'Additional charge for guests traveling with pets.',
    20.00
),
(
    'Extra Cleaning',
    'Additional cleaning service during the stay.',
    30.00
);

------------------------------------------------------------
-- Scenario: 01_plpgsql_fundamentals
------------------------------------------------------------

------------------------------------------------------------
-- PostgreSQL Development Lab
-- Scenario: 01_plpgsql_fundamentals
--
-- AUTO-GENERATED FILE
-- DO NOT EDIT MANUALLY
------------------------------------------------------------

------------------------------------------------------------
-- Source: 01_calculate_stay_cost.sql
------------------------------------------------------------

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

    RETURN v_nights_quantity * v_total_cost;
END;
$$;


------------------------------------------------------------
-- Source: 02_is_property_available.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION is_property_available(
    p_property_id    BIGINT,
    p_check_in_date  DATE,
    p_check_out_date DATE
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_conflict_exists BOOLEAN := FALSE;
    v_nights_quantity NUMERIC := 0;
    v_property_is_active BOOLEAN := NULL;
BEGIN
    v_nights_quantity := p_check_out_date - p_check_in_date;

    IF v_nights_quantity <= 0 THEN
        RAISE EXCEPTION 'dates are incorrect.';
    END IF;

    SELECT p.is_active
    INTO v_property_is_active
    FROM properties AS p
    WHERE p.property_id = p_property_id;

    IF v_property_is_active IS NULL THEN
        RAISE EXCEPTION 'Property % not found.', p_property_id;
    END IF;

    IF NOT v_property_is_active THEN
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



------------------------------------------------------------
-- Source: 03_show_guest_reservations.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION show_guest_reservations(
    p_guest_id BIGINT
)
RETURNS TABLE (
    reservation_id BIGINT,
    property_name  VARCHAR(150),
    check_in       DATE,
    check_out      DATE,
    status         TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_guest_exists BIGINT;
    rec            RECORD;
BEGIN
    SELECT g.guest_id
    INTO v_guest_exists
    FROM guests AS g
    WHERE g.guest_id = p_guest_id;

    IF v_guest_exists IS NULL THEN
        RAISE EXCEPTION 'Guest % not found.', p_guest_id;
    END IF;

    FOR rec IN
        SELECT
            r.reservation_id,
            p.property_name,
            r.check_in_date,
            r.check_out_date,
            r.status
        FROM reservations AS r
        INNER JOIN properties AS p
            ON p.property_id = r.property_id
        WHERE r.guest_id = p_guest_id
    LOOP
        reservation_id := rec.reservation_id;
        property_name  := rec.property_name;
        check_in       := rec.check_in_date;
        check_out      := rec.check_out_date;
        status         := rec.status;

        RETURN NEXT;
    END LOOP;
END;
$$;


------------------------------------------------------------
-- Source: 04_show_guest_reservations_return_query.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION show_guest_reservations_return_query(
    p_guest_id BIGINT
)
RETURNS TABLE (
    reservation_id BIGINT,
    property_name  VARCHAR(150),
    check_in       DATE,
    check_out      DATE,
    status         VARCHAR(20)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_guest_exists BIGINT;
BEGIN
    SELECT g.guest_id
    INTO v_guest_exists
    FROM guests AS g
    WHERE g.guest_id = p_guest_id;

    IF v_guest_exists IS NULL THEN
        RAISE EXCEPTION 'Guest % not found.', p_guest_id;
    END IF;

    RETURN QUERY
        SELECT
            r.reservation_id,
            p.property_name,
            r.check_in_date,
            r.check_out_date,
            r.status
        FROM reservations AS r
        INNER JOIN properties AS p
            ON p.property_id = r.property_id
        WHERE r.guest_id = p_guest_id;
END;
$$;





------------------------------------------------------------
-- Scenario: 02_functions_business_rules
------------------------------------------------------------

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





------------------------------------------------------------
-- Scenario: 03_triggers_and_auditing
------------------------------------------------------------

------------------------------------------------------------
-- PostgreSQL Development Lab
-- Scenario: 03_triggers_and_auditing
--
-- AUTO-GENERATED FILE
-- DO NOT EDIT MANUALLY
------------------------------------------------------------

------------------------------------------------------------
-- Source: 01_update_updated_at_trigger.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_discounts_update_updated_at
BEFORE UPDATE ON discounts
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();

CREATE OR REPLACE TRIGGER trg_guests_update_updated_at
BEFORE UPDATE ON guests
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();

CREATE OR REPLACE TRIGGER trg_properties_update_updated_at
BEFORE UPDATE ON properties
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();

CREATE OR REPLACE TRIGGER trg_reservations_update_updated_at
BEFORE UPDATE ON reservations
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();

CREATE OR REPLACE TRIGGER trg_payments_update_updated_at
BEFORE UPDATE ON payments
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();


------------------------------------------------------------
-- Source: 02_validate_reservation_status.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION validate_reservation_status()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF (OLD.status = 'CONFIRMED' AND NEW.status = 'PENDING') THEN
        RAISE EXCEPTION
            'Invalid reservation status transition from % to %.',
            OLD.status,
            NEW.status;
    END IF;

    IF (OLD.status = 'CANCELLED' AND NEW.status = 'PENDING') THEN
        RAISE EXCEPTION
            'Invalid reservation status transition from % to %.',
            OLD.status,
            NEW.status;
    END IF;

    IF (OLD.status = 'CANCELLED' AND NEW.status = 'CONFIRMED') THEN
        RAISE EXCEPTION
            'Invalid reservation status transition from % to %.',
            OLD.status,
            NEW.status;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_reservations_validate_status
BEFORE UPDATE ON reservations
FOR EACH ROW
EXECUTE FUNCTION validate_reservation_status();


------------------------------------------------------------
-- Source: 03_log_reservation_audit.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION log_reservation_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO reservation_status_audit (
            reservation_id,
            old_status,
            new_status
        )
        VALUES (
            NEW.reservation_id,
            OLD.status,
            NEW.status
        );
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_reservation_audit
AFTER UPDATE OF status ON reservations
FOR EACH ROW
EXECUTE FUNCTION log_reservation_status_change();





------------------------------------------------------------
-- Scenario: 04_error_handling_and_logging
------------------------------------------------------------

------------------------------------------------------------
-- PostgreSQL Development Lab
-- Scenario: 04_error_handling_and_logging
--
-- AUTO-GENERATED FILE
-- DO NOT EDIT MANUALLY
------------------------------------------------------------

------------------------------------------------------------
-- Source: 01_try_create_reservation.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION try_create_reservation(
    p_guest_id    BIGINT,
    p_property_id BIGINT,
    p_check_in    DATE,
    p_check_out   DATE
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id,
        p_property_id,
        p_check_in,
        p_check_out
    );

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION
            'Invalid guest or property identifier.';

    WHEN check_violation THEN
        RAISE EXCEPTION
            'Reservation data violates database constraints.';
END;
$$;


------------------------------------------------------------
-- Source: 02_try_create_reservation_with_logging.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION try_create_reservation_with_logging(
    p_guest_id    BIGINT,
    p_property_id BIGINT,
    p_check_in    DATE,
    p_check_out   DATE
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_sqlstate      VARCHAR(10);
    v_error_message TEXT;
BEGIN
    RETURN create_reservation(
        p_guest_id,
        p_property_id,
        p_check_in,
        p_check_out
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            v_sqlstate := RETURNED_SQLSTATE,
            v_error_message := MESSAGE_TEXT;

        INSERT INTO error_log (
            sql_state,
            error_message,
            function_name
        )
        VALUES (
            v_sqlstate,
            v_error_message,
            'try_create_reservation_with_logging'
        );

        -- This function returns NULL when reservation creation fails.
        -- The caller decides whether the failure should be raised again.
        RETURN NULL;
END;
$$;






------------------------------------------------------------
-- Scenario: 05_advanced_types
------------------------------------------------------------

------------------------------------------------------------
-- PostgreSQL Development Lab
-- Scenario: 05_advanced_types
--
-- AUTO-GENERATED FILE
-- DO NOT EDIT MANUALLY
------------------------------------------------------------

------------------------------------------------------------
-- Source: 01_create_property.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION create_property(
    p_property property_request
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_property_id BIGINT;
BEGIN
    INSERT INTO properties (
        property_name,
        nightly_rate,
        is_active
    )
    VALUES (
        p_property.property_name,
        p_property.nightly_rate,
        p_property.is_active
    )
    RETURNING property_id
    INTO v_property_id;

    RETURN v_property_id;
END;
$$;


------------------------------------------------------------
-- Source: 02_get_reservation_summary.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION get_reservation_summary(
    p_reservation_id BIGINT
)
RETURNS reservation_summary
LANGUAGE plpgsql
AS $$
DECLARE
    v_reservation reservation_summary;
BEGIN
    v_reservation := (
        SELECT ROW(
            r.reservation_id,
            g.full_name,
            p.property_name,
            r.total_amount,
            r.status
        )::reservation_summary
        FROM reservations AS r
        JOIN guests AS g
            ON r.guest_id = g.guest_id
        JOIN properties AS p
            ON r.property_id = p.property_id
        WHERE r.reservation_id = p_reservation_id
    );

    IF v_reservation IS NULL THEN
      RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    RETURN v_reservation;
END;
$$;


------------------------------------------------------------
-- Source: 03_add_services_to_reservation.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION add_services_to_reservation(
    p_reservation_id BIGINT,
    p_service_ids    BIGINT[]
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_unit_price NUMERIC;
    v_service_id BIGINT;
    v_quantity   INTEGER;
BEGIN

    IF NOT EXISTS (
        SELECT 1
        FROM reservations
        WHERE reservation_id = p_reservation_id
    ) THEN
        RAISE EXCEPTION
            'Reservation % not found.',
            p_reservation_id;
    END IF;

    DELETE FROM reservation_services
    WHERE reservation_id = p_reservation_id;

    IF p_service_ids IS NULL
       OR cardinality(p_service_ids) = 0 THEN
        RETURN;
    END IF;

    FOR v_service_id, v_quantity IN
        SELECT
            service_id,
            COUNT(*)::INTEGER
        FROM unnest(p_service_ids) AS item(service_id)
        GROUP BY service_id
    LOOP
        SELECT price
        INTO v_unit_price
        FROM services
        WHERE service_id = v_service_id;

        IF v_unit_price IS NULL THEN
            RAISE EXCEPTION 'Service % not found.', v_service_id;
        END IF;

        INSERT INTO reservation_services (
            reservation_id,
            service_id,
            quantity,
            unit_price
        )
        VALUES (
            p_reservation_id,
            v_service_id,
            v_quantity,
            v_unit_price
        );
    END LOOP;
END;
$$;






------------------------------------------------------------
-- Scenario: 06_jsonb
------------------------------------------------------------

------------------------------------------------------------
-- PostgreSQL Development Lab
-- Scenario: 06_jsonb
--
-- AUTO-GENERATED FILE
-- DO NOT EDIT MANUALLY
------------------------------------------------------------

------------------------------------------------------------
-- Source: 01_update_property_metadata.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION update_property_metadata(
    p_property_id BIGINT,
    p_metadata    JSONB
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM properties
        WHERE property_id = p_property_id
    ) THEN
        RAISE EXCEPTION
            'Property % not found.',
            p_property_id;
    END IF;

    UPDATE properties
    SET metadata = p_metadata
    WHERE property_id = p_property_id;
END;
$$;


------------------------------------------------------------
-- Source: 02_jsonb_queries.sql
------------------------------------------------------------

/*
==========================================
Retrieve the complete metadata document
==========================================
*/

SELECT
    property_name,
    metadata
FROM properties
where metadata is not null;

/*
==========================================
Access a top-level object
==========================================
*/

SELECT
    property_name,
    metadata -> 'amenities' AS amenities
FROM properties
where metadata is not null;

/*
==========================================
Extract a scalar value
==========================================
*/

SELECT
    property_name,
    metadata ->> 'languages' AS languages
FROM properties
where metadata is not null;

/*
==========================================
Access nested values
==========================================
*/

SELECT
    property_name,
    metadata -> 'check_in' ->> 'from' AS check_in_from,
    metadata -> 'check_in' ->> 'to'   AS check_in_to
FROM properties
where metadata is not null;

/*
==========================================
Filter: Properties that allow pets
==========================================
*/

SELECT
    property_name
FROM properties
WHERE metadata -> 'house_rules' ->> 'pets_allowed' = 'false';


------------------------------------------------------------
-- Source: 03_update_jsonb_fields.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION update_property_parking(
    p_property_id BIGINT,
    p_has_parking BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM properties
        WHERE property_id = p_property_id
    ) THEN
        RAISE EXCEPTION
            'Property % not found.',
            p_property_id;
    END IF;

    -- If the "amenities" structure does not exist, jsonb_set() leaves the
    -- JSON document unchanged because it cannot create missing intermediate keys.
    UPDATE properties
    SET metadata = jsonb_set(
        COALESCE(metadata, '{}'::jsonb),
        '{amenities,parking}',
        to_jsonb(p_has_parking)
    )
    WHERE property_id = p_property_id;
END;
$$;



------------------------------------------------------------
-- Source: 04_how_jsonb_set_works.sql
------------------------------------------------------------

SELECT jsonb_set(
    '{"amenities":{"wifi":true,"parking":false}}'::jsonb,
    '{amenities,parking}',
    'true'::jsonb
);


/*

result:

{
  "amenities": {
    "wifi": true,
    "parking": true
  }
}


*/


------------------------------------------------------------
-- Source: 05_add_services_to_reservation_jsonb.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION add_services_to_reservation(
    p_reservation_id BIGINT,
    p_services       JSONB
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_service_id BIGINT;
    v_service    JSONB;
    v_unit_price NUMERIC;
    v_quantity   INTEGER;
BEGIN

    IF NOT EXISTS (
        SELECT 1
        FROM reservations
        WHERE reservation_id = p_reservation_id
    ) THEN
        RAISE EXCEPTION
            'Reservation % not found.',
            p_reservation_id;
    END IF;

    IF p_services IS NULL THEN
        RETURN;
    END IF;

    IF jsonb_typeof(p_services) <> 'array' THEN
        RAISE EXCEPTION
            'Expected a JSON array.';
    END IF;

    IF jsonb_array_length(p_services) = 0 THEN
        RETURN;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements(p_services) AS item(service_data)
        GROUP BY (service_data ->> 'service_id')::BIGINT
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION
            'The service list contains repeated services.';
    END IF;

    DELETE FROM reservation_services
    WHERE reservation_id = p_reservation_id;

    FOR v_service IN
        SELECT *
        FROM jsonb_array_elements(p_services)
    LOOP
        v_service_id := (v_service ->> 'service_id')::BIGINT;
        v_quantity := (v_service ->> 'quantity')::INTEGER;

        IF v_quantity IS NULL OR v_quantity <= 0 THEN
            RAISE EXCEPTION
                'Service quantity must be greater than zero.';
        END IF;

        SELECT price
        INTO v_unit_price
        FROM services
        WHERE service_id = v_service_id;

        IF v_unit_price IS NULL THEN
            RAISE EXCEPTION 'Service % not found.', v_service_id;
        END IF;

        INSERT INTO reservation_services (
            reservation_id,
            service_id,
            quantity,
            unit_price
        )
        VALUES (
            p_reservation_id,
            v_service_id,
            v_quantity,
            v_unit_price
        );
    END LOOP;
END;
$$;







