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
DROP SEQUENCE IF EXISTS property_code_number_seq;

CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE SEQUENCE property_code_number_seq;


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

    nightly_rate    NUMERIC(12,2)
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

