DROP TABLE IF EXISTS reservation_services CASCADE;
DROP TABLE IF EXISTS services CASCADE;
DROP TABLE IF EXISTS error_log CASCADE;
DROP TABLE IF EXISTS reservation_status_audit CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS reservations CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS properties CASCADE;
DROP TABLE IF EXISTS guests CASCADE;
DROP TABLE IF EXISTS discounts CASCADE;
DROP TABLE IF EXISTS app_settings CASCADE;
DROP SEQUENCE IF EXISTS property_code_number_seq;

CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE SEQUENCE property_code_number_seq;


CREATE TABLE users (
    user_id       BIGSERIAL PRIMARY KEY,
    user_code     VARCHAR(30) NOT NULL,
    email         VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name     VARCHAR(100) NOT NULL,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMPTZ,

    CONSTRAINT uq_users_user_code
        UNIQUE (user_code),

    CONSTRAINT uq_users_email
        UNIQUE (email),

    CONSTRAINT chk_users_user_code_format
        CHECK (user_code ~ '^[A-Z0-9]+(-[A-Z0-9]+)*$')
);


CREATE TABLE guests (
    guest_id      BIGSERIAL PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    email         VARCHAR(255) NOT NULL UNIQUE,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    document_type VARCHAR(30),
    document_number VARCHAR(50),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMPTZ,

    CONSTRAINT chk_guests_document_pair
        CHECK (
            (document_type IS NULL AND document_number IS NULL)
            OR
            (document_type IS NOT NULL AND document_number IS NOT NULL)
        ),

    CONSTRAINT uq_guests_document
        UNIQUE (document_type, document_number)

);

CREATE OR REPLACE FUNCTION normalize_guest_document()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.document_type := NULLIF(UPPER(BTRIM(NEW.document_type)), '');
    NEW.document_number := NULLIF(BTRIM(NEW.document_number), '');
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_guests_normalize_document
BEFORE INSERT OR UPDATE OF document_type, document_number ON guests
FOR EACH ROW
EXECUTE FUNCTION normalize_guest_document();

CREATE TABLE properties (
    property_id     BIGSERIAL PRIMARY KEY,
    property_name   VARCHAR(150) NOT NULL,

    property_type   VARCHAR(20)
                    NOT NULL
                    CHECK (
                        property_type IN (
                            'CABIN',
                            'APARTMENT',
                            'ROOM'
                        )
                    ),

    property_code   VARCHAR(10)
                    NOT NULL
                    UNIQUE
                    CHECK (property_code <> '')
                    CHECK (property_code ~ '^[A-Z]{3}-[0-9]{4}$'),

    nightly_rate    NUMERIC(16,6)
                     NOT NULL
                     CHECK (nightly_rate >= 0),

    is_active       BOOLEAN NOT NULL DEFAULT TRUE,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at      TIMESTAMPTZ,

    metadata        JSONB  
);

CREATE OR REPLACE FUNCTION set_property_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_prefix VARCHAR(3);
    v_number BIGINT;
BEGIN
    IF NEW.property_code IS NULL OR BTRIM(NEW.property_code) = '' THEN
        v_prefix := CASE NEW.property_type
            WHEN 'CABIN' THEN 'CAB'
            WHEN 'APARTMENT' THEN 'APT'
            WHEN 'ROOM' THEN 'ROM'
        END;

        IF v_prefix IS NULL THEN
            RAISE EXCEPTION 'Invalid property type: %', NEW.property_type
                USING ERRCODE = '23514';
        END IF;

        LOOP
            v_number := nextval('property_code_number_seq');

            IF v_number > 9999 THEN
                RAISE EXCEPTION 'Property code sequence exhausted at %', v_number;
            END IF;

            NEW.property_code := v_prefix || '-' || LPAD(v_number::TEXT, 4, '0');
            EXIT WHEN NOT EXISTS (
                SELECT 1
                FROM properties
                WHERE property_code = NEW.property_code
            );
        END LOOP;
    ELSE
        NEW.property_code := UPPER(BTRIM(NEW.property_code));
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_properties_set_property_code
BEFORE INSERT OR UPDATE OF property_code, property_type ON properties
FOR EACH ROW
EXECUTE FUNCTION set_property_code();

CREATE TABLE reservations (
    reservation_id      BIGSERIAL PRIMARY KEY,

    guest_id            BIGINT NOT NULL,

    property_id         BIGINT NOT NULL,

    created_by_user_id  BIGINT NOT NULL,

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

    total_amount        NUMERIC(16,6)
                        NOT NULL
                        DEFAULT 0
                        CHECK (total_amount >= 0),

    currency_code       VARCHAR(3)
                        NOT NULL
                        CHECK (currency_code ~ '^[A-Z]{3}$'),

    exchange_rate       NUMERIC(20,10)
                        NOT NULL
                        CHECK (exchange_rate > 0),

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

    CONSTRAINT fk_reservations_created_by_user
        FOREIGN KEY (created_by_user_id)
        REFERENCES users(user_id),

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

CREATE INDEX idx_reservations_created_by_user_id
    ON reservations(created_by_user_id);

CREATE TABLE payments (
    payment_id          BIGSERIAL PRIMARY KEY,

    reservation_id      BIGINT NOT NULL,

    payment_amount      NUMERIC(16,6)
                        NOT NULL
                        CHECK (payment_amount > 0),

    exchange_rate       NUMERIC(20,10)
                        NOT NULL
                        CHECK (exchange_rate > 0),

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

    description     VARCHAR(255),

    CONSTRAINT chk_app_settings_base_currency_code
        CHECK (
            setting_key <> 'base_currency_code'
            OR setting_value ~ '^[A-Z]{3}$'
        )

);

CREATE OR REPLACE FUNCTION validate_currency_exchange_rate(
    p_currency_code VARCHAR,
    p_exchange_rate NUMERIC
)
RETURNS VARCHAR
LANGUAGE plpgsql
AS $$
DECLARE
    v_currency_code VARCHAR(3);
    v_base_currency_code VARCHAR(3);
BEGIN
    v_currency_code := UPPER(BTRIM(p_currency_code));

    IF v_currency_code IS NULL OR v_currency_code !~ '^[A-Z]{3}$' THEN
        RAISE EXCEPTION 'Currency code must be a three-letter ISO 4217 code.';
    END IF;

    IF p_exchange_rate IS NULL OR p_exchange_rate <= 0 THEN
        RAISE EXCEPTION 'Exchange rate must be greater than zero.';
    END IF;

    SELECT setting_value
    INTO v_base_currency_code
    FROM app_settings
    WHERE setting_key = 'base_currency_code';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Setting "base_currency_code" not found.';
    END IF;

    IF v_currency_code = v_base_currency_code AND p_exchange_rate <> 1 THEN
        RAISE EXCEPTION 'Exchange rate must be 1 when the currency is the base currency (%).',
            v_base_currency_code;
    END IF;

    RETURN v_currency_code;
END;
$$;

CREATE OR REPLACE FUNCTION validate_reservation_currency_snapshot()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.currency_code IS NULL AND NEW.exchange_rate IS NULL THEN
        SELECT setting_value, 1::NUMERIC(20,10)
        INTO NEW.currency_code, NEW.exchange_rate
        FROM app_settings
        WHERE setting_key = 'base_currency_code';
    END IF;

    NEW.currency_code := validate_currency_exchange_rate(
        NEW.currency_code,
        NEW.exchange_rate
    );
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_reservations_validate_currency_snapshot
BEFORE INSERT OR UPDATE OF currency_code, exchange_rate ON reservations
FOR EACH ROW
EXECUTE FUNCTION validate_reservation_currency_snapshot();

CREATE OR REPLACE FUNCTION validate_payment_exchange_rate()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_currency_code VARCHAR(3);
BEGIN
    SELECT r.currency_code
    INTO v_currency_code
    FROM reservations AS r
    WHERE r.reservation_id = NEW.reservation_id;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    IF NEW.exchange_rate IS NULL
       AND v_currency_code = (
           SELECT setting_value FROM app_settings
           WHERE setting_key = 'base_currency_code'
       ) THEN
        NEW.exchange_rate := 1::NUMERIC(20,10);
    END IF;

    PERFORM validate_currency_exchange_rate(v_currency_code, NEW.exchange_rate);
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_payments_validate_exchange_rate
BEFORE INSERT OR UPDATE OF reservation_id, exchange_rate ON payments
FOR EACH ROW
EXECUTE FUNCTION validate_payment_exchange_rate();

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
    price NUMERIC(14,6) NOT NULL,
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
    unit_price NUMERIC(14,6) NOT NULL,

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

