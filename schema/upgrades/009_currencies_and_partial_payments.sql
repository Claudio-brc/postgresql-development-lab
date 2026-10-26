-- Apply after 008_reservation_economic_lifecycle.sql with psql.
-- Legacy monetary rows are preserved and classified in the configured ARS
-- base currency at rate 1 because no earlier currency metadata exists.

BEGIN;

INSERT INTO app_settings (setting_key, setting_value, description)
VALUES (
    'base_currency_code',
    'ARS',
    'Currency used for consolidated financial reporting'
)
ON CONFLICT (setting_key) DO NOTHING;

ALTER TABLE reservations
    ADD COLUMN IF NOT EXISTS currency_code VARCHAR(3),
    ADD COLUMN IF NOT EXISTS exchange_rate NUMERIC(20,10);

ALTER TABLE payments
    ADD COLUMN IF NOT EXISTS exchange_rate NUMERIC(20,10);

UPDATE reservations
SET currency_code = get_setting('base_currency_code'),
    exchange_rate = 1::NUMERIC(20,10)
WHERE currency_code IS NULL OR exchange_rate IS NULL;

UPDATE payments
SET exchange_rate = 1::NUMERIC(20,10)
WHERE exchange_rate IS NULL;

ALTER TABLE reservations
    ALTER COLUMN currency_code SET NOT NULL,
    ALTER COLUMN exchange_rate SET NOT NULL;

ALTER TABLE payments
    ALTER COLUMN exchange_rate SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'reservations'::REGCLASS
          AND conname = 'chk_reservations_currency_code'
    ) THEN
        ALTER TABLE reservations
            ADD CONSTRAINT chk_reservations_currency_code
            CHECK (currency_code ~ '^[A-Z]{3}$');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'reservations'::REGCLASS
          AND conname = 'chk_reservations_exchange_rate'
    ) THEN
        ALTER TABLE reservations
            ADD CONSTRAINT chk_reservations_exchange_rate
            CHECK (exchange_rate > 0);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'payments'::REGCLASS
          AND conname = 'chk_payments_exchange_rate'
    ) THEN
        ALTER TABLE payments
            ADD CONSTRAINT chk_payments_exchange_rate
            CHECK (exchange_rate > 0);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'app_settings'::REGCLASS
          AND conname = 'chk_app_settings_base_currency_code'
    ) THEN
        ALTER TABLE app_settings
            ADD CONSTRAINT chk_app_settings_base_currency_code
            CHECK (
                setting_key <> 'base_currency_code'
                OR setting_value ~ '^[A-Z]{3}$'
            );
    END IF;
END;
$$;

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

    SELECT setting_value INTO v_base_currency_code
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
        NEW.currency_code, NEW.exchange_rate
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_reservations_validate_currency_snapshot ON reservations;
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
    SELECT r.currency_code INTO v_currency_code
    FROM reservations AS r
    WHERE r.reservation_id = NEW.reservation_id;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    IF NEW.exchange_rate IS NULL
       AND v_currency_code = get_setting('base_currency_code') THEN
        NEW.exchange_rate := 1::NUMERIC(20,10);
    END IF;

    PERFORM validate_currency_exchange_rate(v_currency_code, NEW.exchange_rate);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_payments_validate_exchange_rate ON payments;
CREATE TRIGGER trg_payments_validate_exchange_rate
BEFORE INSERT OR UPDATE OF reservation_id, exchange_rate ON payments
FOR EACH ROW
EXECUTE FUNCTION validate_payment_exchange_rate();

-- Reuse the canonical scenario sources so upgrade and clean-install behavior
-- cannot drift. \ir resolves paths relative to this upgrade file in psql.
\ir ../../scenarios/08_currencies_and_partial_payments/01_base_currency_reporting.sql
\ir ../../scenarios/08_currencies_and_partial_payments/02_initialize_reservation.sql
\ir ../../scenarios/08_currencies_and_partial_payments/03_process_reservation_payment.sql
\ir ../../scenarios/08_currencies_and_partial_payments/04_create_reservation.sql

COMMIT;
