-- Run only in a disposable database. This builds a minimal pre-013 namespace,
-- applies the real upgrade twice, and removes the fixture afterward.

CREATE SCHEMA property_capacity_upgrade_test;
SET search_path = property_capacity_upgrade_test, public;

CREATE TYPE property_request AS (
    property_name VARCHAR(150),
    nightly_rate NUMERIC(16,6),
    is_active BOOLEAN,
    property_type VARCHAR(20),
    property_code VARCHAR(10),
    metadata JSONB
);

CREATE TABLE properties (
    property_id BIGSERIAL PRIMARY KEY,
    property_name VARCHAR(150) NOT NULL,
    nightly_rate NUMERIC(16,6) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    property_type VARCHAR(20) NOT NULL,
    property_code VARCHAR(10),
    metadata JSONB
);

CREATE TABLE reservations (
    reservation_id BIGSERIAL PRIMARY KEY,
    guest_id BIGINT NOT NULL,
    property_id BIGINT NOT NULL REFERENCES properties(property_id),
    created_by_user_id BIGINT NOT NULL,
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    total_amount NUMERIC(16,6) NOT NULL DEFAULT 0,
    currency_code VARCHAR(3) NOT NULL DEFAULT 'ARS',
    exchange_rate NUMERIC(20,10) NOT NULL DEFAULT 1
);

CREATE FUNCTION validate_currency_exchange_rate(VARCHAR, NUMERIC)
RETURNS VARCHAR LANGUAGE SQL IMMUTABLE AS
$$ SELECT UPPER($1) $$;

CREATE FUNCTION validate_booking_dates(DATE, DATE)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    IF $2 <= $1 THEN
        RAISE EXCEPTION 'dates are incorrect.';
    END IF;
END;
$$;

CREATE FUNCTION can_guest_book(BIGINT)
RETURNS BOOLEAN LANGUAGE SQL IMMUTABLE AS
$$ SELECT TRUE $$;

CREATE FUNCTION calculate_booking_total(BIGINT, DATE, DATE)
RETURNS NUMERIC LANGUAGE SQL IMMUTABLE AS
$$ SELECT 100::NUMERIC $$;

CREATE FUNCTION replace_reservation_services(BIGINT, JSONB)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    RETURN;
END;
$$;

CREATE FUNCTION get_setting(VARCHAR)
RETURNS VARCHAR LANGUAGE SQL IMMUTABLE AS
$$ SELECT 'ARS'::VARCHAR $$;

CREATE FUNCTION process_reservation_payment(BIGINT, NUMERIC, VARCHAR, NUMERIC)
RETURNS BIGINT LANGUAGE SQL AS
$$ SELECT 1::BIGINT $$;

INSERT INTO properties (
    property_id, property_name, nightly_rate, property_type
) VALUES
    (101, 'Legacy Property One', 100, 'ROOM'),
    (102, 'Legacy Property Two', 200, 'APARTMENT');

INSERT INTO reservations (
    reservation_id, guest_id, property_id, created_by_user_id,
    check_in_date, check_out_date, status, total_amount
) VALUES
    (201, 1, 101, 1, DATE '2027-01-01', DATE '2027-01-02', 'PENDING', 100),
    (202, 2, 102, 1, DATE '2027-02-01', DATE '2027-02-02', 'CONFIRMED', 200);

\ir ../../schema/upgrades/013_property_capacity.sql
\ir ../../schema/upgrades/013_property_capacity.sql

DO $$
BEGIN
    IF (SELECT COUNT(*) FROM properties) <> 2
       OR (SELECT COUNT(*) FROM reservations) <> 2
       OR NOT EXISTS (SELECT 1 FROM properties WHERE property_id = 101)
       OR NOT EXISTS (SELECT 1 FROM properties WHERE property_id = 102)
       OR NOT EXISTS (SELECT 1 FROM reservations WHERE reservation_id = 201)
       OR NOT EXISTS (SELECT 1 FROM reservations WHERE reservation_id = 202) THEN
        RAISE EXCEPTION 'Upgrade did not preserve legacy rows and identifiers';
    END IF;

    IF EXISTS (SELECT 1 FROM properties WHERE max_guests <> 1)
       OR EXISTS (SELECT 1 FROM reservations WHERE guests_count <> 1) THEN
        RAISE EXCEPTION 'Historical compatibility values were not initialized to one';
    END IF;

    IF to_regprocedure(
        'property_capacity_upgrade_test.is_property_available(bigint,date,date,integer)'
    ) IS NULL
       OR to_regprocedure(
        'property_capacity_upgrade_test.create_reservation(bigint,bigint,date,date,integer,bigint)'
    ) IS NULL THEN
        RAISE EXCEPTION 'Upgrade did not install guest-aware functions';
    END IF;

    BEGIN
        UPDATE properties SET max_guests = 0 WHERE property_id = 101;
        RAISE EXCEPTION 'Invalid property capacity was accepted';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    BEGIN
        UPDATE reservations SET guests_count = 0 WHERE reservation_id = 201;
        RAISE EXCEPTION 'Invalid reservation guest count was accepted';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;
END;
$$;

RESET search_path;
DROP SCHEMA property_capacity_upgrade_test CASCADE;
